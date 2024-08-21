//
//  SpotifyController.swift
//  spotifyIOSSDKtest
//
//  Created by Srijan Kunta on 7/5/24.
//

import Foundation
import SwiftUI
import SpotifyiOS
import Combine
import CoreMotion

@MainActor
final class SpotifyController: NSObject, ObservableObject {
    
    let spotifyClientID: String
    let spotifyRedirectURL: URL
    
    override init() {
        
        // Store the values from Environment
        spotifyClientID = Environment.apiKey
        
        guard let redirectURL = URL(string: Environment.baseURL) else {
            fatalError("Invalid Redirect URL")
        }
        
        spotifyRedirectURL = redirectURL
        
        super.init()
        setupCadenceObserver()
        
    }
    
    var accessToken: String? = nil
    private var connectCancellable: AnyCancellable?
    private var disconnectCancellable: AnyCancellable?
    private var isFetchingRecommendation: Bool = false
    
    @Published var currentTrackURI: String?
    @Published var currentTrackName: String?
    @Published var currentTrackArtist: String?
    @Published var currentTrackDuration: Int?
    @Published var currentTrackImage: UIImage?
    @Published var currentTrackTempo: Double?
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var userDisplayName: String? = nil
    @Published var isPlaying: Bool = false
    @Published var recommendedTracks: [SpotifyTrack] = []
    @Published var internalQueue: [SpotifyTrack] = []  // Internal queue to track songs
    @Published var currentCadence: Double = 0.0
    @Published var userProfileImage: UIImage? = nil
    
    let coreMotionManager = CoreMotionManager()
    private var cancellables: Set<AnyCancellable> = []
    
    private var selectedGenres: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: "selectedGenres") ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedGenres")
        }
    }
    
    lazy var configuration = SPTConfiguration(
        clientID: spotifyClientID,
        redirectURL: spotifyRedirectURL
    )
    
    lazy var scopes: SPTScope = [
        .userModifyPlaybackState,
        .userReadPlaybackState,
        .userReadCurrentlyPlaying,
        .appRemoteControl
    ]
    
    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()
    

    

    private func setupCadenceObserver() {
        coreMotionManager.$currentCadence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cadence in
                self?.currentCadence = cadence
                Task {
                    await self?.updateQueueIfNeeded(for: cadence * 60) // Convert to BPM
                }
            }
            .store(in: &cancellables)
    }
    
    func startTrackingCadence() {
        
        coreMotionManager.startUpdating()
        startBackgroundTask()
    }
    
    func stopTrackingCadence() {
        coreMotionManager.stopUpdating()
        endBackgroundTask()
    }

    private func startBackgroundTask() {
        UIApplication.shared.beginBackgroundTask(withName: "SpotifyQueueUpdate") {
            self.endBackgroundTask()
        }
        
        Task.detached { [weak self] in
            await self?.monitorCadenceAndQueue()
        }
    }

    private func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(.invalid)
    }

    private func monitorCadenceAndQueue() async {
        while UIApplication.shared.backgroundTimeRemaining > 1.0 {
            await self.updateQueueIfNeeded(for: self.currentCadence * 60)
            // Add a small delay to avoid constant looping without any break.
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }
    }
    
    func setAccessToken(from url: URL) {
        let parameters = appRemote.authorizationParameters(from: url)
        
        if let accessToken = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = accessToken
            self.accessToken = accessToken
            fetchUserProfile() // Fetch the user profile after setting the access token
        } else if let errorDescription = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print("Error: \(errorDescription)")
        }
    }
    
    func authorizeIfNeeded(completion: @escaping () -> Void) {
        if !appRemote.isConnected {
            authorize {
                self.connect(completion: completion)
            }
        } else {
            completion()
        }
    }
    
    func playPause() {
        authorizeIfNeeded {
            if let playerAPI = self.appRemote.playerAPI {
                playerAPI.getPlayerState { (result, error) in
                    if let error = error {
                        print("Error getting player state: \(error.localizedDescription)")
                    } else if let playerState = result as? SPTAppRemotePlayerState {
                        if playerState.isPaused {
                            playerAPI.resume { [weak self] (result, error) in
                                if let error = error {
                                    print("Error resuming: \(error.localizedDescription)")
                                } else {
                                    DispatchQueue.main.async {
                                        self?.isPlaying = true
                                    }
                                }
                            }
                        } else {
                            playerAPI.pause { [weak self] (result, error) in
                                if let error = error {
                                    print("Error pausing: \(error.localizedDescription)")
                                } else {
                                    DispatchQueue.main.async {
                                        self?.isPlaying = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func skipToNextTrack() {
        authorizeIfNeeded {
            if let playerAPI = self.appRemote.playerAPI {
                playerAPI.skip(toNext:) { result, error in
                    if let error = error {
                        print("Error skipping to next track: \(error.localizedDescription)")
                    } else if let result = result as? Bool, result {
                        print("Successfully skipped to the next track")
                    } else {
                        print("Failed to skip to next track")
                    }
                }
            } else {
                print("PlayerAPI not available")
            }
        }
    }
    
    func skipToPreviousTrack() {
        authorizeIfNeeded {
            if let playerAPI = self.appRemote.playerAPI {
                playerAPI.skip(toPrevious:) { result, error in
                    if let error = error {
                        print("Error skipping to previous track: \(error.localizedDescription)")
                    } else if let result = result as? Bool, result {
                        print("Successfully skipped to the previous track")
                    } else {
                        print("Failed to skip to previous track")
                    }
                }
            } else {
                print("PlayerAPI not available")
            }
        }
    }
    
    func authorize(completion: @escaping () -> Void) {
        self.appRemote.authorizeAndPlayURI("") { success in
            completion()
        }
    }

    func connect(completion: @escaping () -> Void) {
        if let _ = self.appRemote.connectionParameters.accessToken {
            self.appRemote.connect()
            completion()
        } else {
            completion()
        }
    }
    
    func authorizeIfNeededAsync() async {
        if !appRemote.isConnected {
            await authorizeAsync()
            connectAsync()
        }
    }

    func authorizeAsync() async {
        await withCheckedContinuation { continuation in
            self.appRemote.authorizeAndPlayURI("") { success in
                continuation.resume()
            }
        }
    }

    func connectAsync() {
        if let _ = self.appRemote.connectionParameters.accessToken {
            self.appRemote.connect()
        }
    }
    
    func fetchImage() {
        authorizeIfNeeded {
            self.appRemote.playerAPI?.getPlayerState { (result, error) in
                if let error = error {
                    print("Error getting player state: \(error)")
                } else if let playerState = result as? SPTAppRemotePlayerState {
                    self.appRemote.imageAPI?.fetchImage(forItem: playerState.track, with: CGSize(width: 300, height: 300), callback: { (image, error) in
                        if let error = error {
                            print("Error fetching track image: \(error.localizedDescription)")
                        } else if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self.currentTrackImage = image
                            }
                        }
                    })
                }
            }
        }
    }
    
    func fetchAudioFeatures(for trackURI: String) {
        guard let accessToken = self.accessToken else {
            print("No access token available")
            return
        }
        
        let trackID = trackURI.split(separator: ":").last ?? ""
        let url = URL(string: "https://api.spotify.com/v1/audio-features/\(trackID)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            guard error == nil else {
                print("Error fetching audio features: \(error!.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let tempo = json["tempo"] as? Double {
                    DispatchQueue.main.async {
                        self.currentTrackTempo = tempo
                    }
                }
            } catch {
                print("Error parsing audio features data: \(error.localizedDescription)")
            }
        }

        task.resume()
    }
    
    func fetchRecommendation(for tempo: Double) {
        guard !isFetchingRecommendation else {
            return
        }

        isFetchingRecommendation = true  // Set the flag to true to prevent further calls

        guard let accessToken = self.accessToken else {
            print("No access token available")
            Task { @MainActor in
                self.isFetchingRecommendation = false  // Reset flag on failure
            }
            return
        }

        let minTempo = max(0, tempo - 1.5)
        let maxTempo = tempo + 2
        let targetDanceability = Double.random(in: 0.75..<1)

        // Convert selectedGenres array to a comma-separated string
        let genreSeeds = selectedGenres.joined(separator: ",")
        let urlString = "https://api.spotify.com/v1/recommendations?limit=10&seed_genres=\(genreSeeds)&min_danceability=0.55&target_danceability=\(targetDanceability)&min_tempo=\(minTempo)&max_tempo=\(maxTempo)"

        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            Task { @MainActor in
                self.isFetchingRecommendation = false  // Reset flag on failure
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            Task { @MainActor in
                self.isFetchingRecommendation = false  // Ensure flag is reset after the request
            }

            guard error == nil else {
                print("Error fetching recommendation: \(error!.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let tracks = json["tracks"] as? [[String: Any]] {

                    // Choose a random track from the fetched tracks
                    if let randomTrackJson = tracks.randomElement(),
                       let randomTrack = SpotifyTrack(json: randomTrackJson) {
                        
                        Task { @MainActor in
                            await self.addTrackToQueue(randomTrack)
                        }
                    }
                }
            } catch {
                print("Error parsing recommendation data: \(error.localizedDescription)")
            }
        }
        task.resume()
    }


    func addTrackToQueue(_ track: SpotifyTrack) async {
        await authorizeIfNeededAsync()

        guard appRemote.isConnected, let playerAPI = appRemote.playerAPI else {
            print("Not connected to Spotify or playerAPI not available")
            return
        }

        playerAPI.enqueueTrackUri(track.uri) { [weak self] result, error in
            if let error = error {
                print("Error adding track to queue: \(error.localizedDescription)")
            } else {
                print("Track added to queue")
                DispatchQueue.main.async {
                    self?.internalQueue.append(track)  // Add to internal queue
                }
            }
        }
    }

    @MainActor
    func updateQueueIfNeeded(for tempo: Double) async {
        @AppStorage("isManualMode") var isManualMode: Bool = false
        @AppStorage("manualTempo") var manualTempo: Double = 120.0
        
        let tempoToUse = isManualMode ? manualTempo : tempo

        // Check if there's any song in the queue
        if internalQueue.isEmpty {
            coreMotionManager.updateCadence()  // Update cadence before fetching a recommendation
            fetchRecommendation(for: tempoToUse)
        }
    }

    func trackDidFinishPlaying() {
        if !internalQueue.isEmpty {
            internalQueue.removeFirst()  // Remove the first song in the queue
            // Check if we need to add a new song
            Task {
                await updateQueueIfNeeded(for: currentCadence * 60)
            }
        }
    }

    struct SpotifyTrack: Identifiable {
        let id = UUID()
        let uri: String
        let name: String
        let artist: String
        let duration: Int
        let imageUrl: String

        init?(json: [String: Any]) {
            guard let uri = json["uri"] as? String,
                  let name = json["name"] as? String,
                  let artists = json["artists"] as? [[String: Any]],
                  let artistName = artists.first?["name"] as? String,
                  let duration = json["duration_ms"] as? Int,
                  let album = json["album"] as? [String: Any],
                  let images = album["images"] as? [[String: Any]],
                  let imageUrl = images.first?["url"] as? String else {
                return nil
            }
            self.uri = uri
            self.name = name
            self.artist = artistName
            self.duration = duration / 1000 // Convert to seconds
            self.imageUrl = imageUrl
        }
    }
    
    
}

struct UserProfileView: View {
    var userDisplayName: String?
    var userProfileImage: UIImage?

    var body: some View {
        HStack {
            if let userProfileImage = userProfileImage {
                Image(uiImage: userProfileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            
            if let userDisplayName = userDisplayName {
                Text(userDisplayName)
                    .font(.headline)
            } else {
                Text("Not logged in")
                    .font(.headline)
            }
        }
        .padding()
    }
}

extension SpotifyController: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        self.appRemote = appRemote
        self.appRemote.playerAPI?.delegate = self
        self.appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
            if let error = error {
                print("Error subscribing to player state: \(error.localizedDescription)")
            } else {
                print("Successfully subscribed to player state")
                // Fetch the current player state after subscribing
                self.fetchCurrentPlayerState()
            }
        })
    }

    // This is the new method to fetch the current player state
    func fetchCurrentPlayerState() {
        self.appRemote.playerAPI?.getPlayerState { [weak self] (result, error) in
            if let error = error {
                print("Error getting player state: \(error.localizedDescription)")
            } else if let playerState = result as? SPTAppRemotePlayerState {
                self?.playerStateDidChange(playerState)
            }
        }
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        if let error = error {
            print("Failed to connect to Spotify: \(error.localizedDescription)")
            alertMessage = "Failed to connect to Spotify: \(error.localizedDescription)"
        } else {
            print("Failed to connect to Spotify")
            alertMessage = "Failed to connect to Spotify"
        }
        showAlert = true
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        if let error = error {
            print("Disconnected from Spotify: \(error.localizedDescription)")
            alertMessage = "Disconnected from Spotify: \(error.localizedDescription)"
        } else {
            print("Disconnected from Spotify")
            alertMessage = "Disconnected from Spotify"
        }
        showAlert = true
    }
}

extension SpotifyController: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        self.currentTrackURI = playerState.track.uri
        self.currentTrackName = playerState.track.name
        self.currentTrackArtist = playerState.track.artist.name
        self.currentTrackDuration = Int(playerState.track.duration) / 1000 // playerState.track.duration is in milliseconds
        self.isPlaying = !playerState.isPaused
        fetchImage()
        fetchAudioFeatures(for: playerState.track.uri)

        if playerState.isPaused {
            // If the track is paused, don't remove it from the queue
            return
        }

        // If the current track changes (i.e., the previous track finished or was skipped)
        if let firstTrack = internalQueue.first, firstTrack.uri == playerState.track.uri {
            trackDidFinishPlaying()
        }
    }
}

extension SpotifyController {
    func fetchUserProfile() {
        guard let accessToken = self.accessToken else {
            print("No access token available")
            return
        }

        let url = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard error == nil else {
                print("Error fetching user profile: \(error!.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let displayName = json["display_name"] as? String {
                        DispatchQueue.main.async {
                            self?.userDisplayName = displayName
                        }
                    }
                    if let images = json["images"] as? [[String: Any]],
                       let firstImage = images.first,
                       let urlString = firstImage["url"] as? String,
                       let imageURL = URL(string: urlString) {
                        URLSession.shared.dataTask(with: imageURL) { data, response, error in
                            if let data = data, let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    self?.userProfileImage = image
                                }
                            }
                        }.resume()
                    }
                } else {
                    print("Error: JSON is not a dictionary")
                }
            } catch {
                print("Error parsing user profile data: \(error.localizedDescription)")
            }
        }

        task.resume()
    }
}
