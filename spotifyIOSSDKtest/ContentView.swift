//
//  ContentView.swift
//  spotifyIOSSDKtest
//
//  Created by Srijan Kunta on 7/5/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var spotifyController = SpotifyController()
    @State private var isTracking: Bool = false
    @AppStorage("isManualMode") private var isManualMode: Bool = false
    @AppStorage("manualTempo") private var manualTempo: Double = 120.0
    @FocusState private var isTempoInputFocused: Bool
    @AppStorage("hasChosenGenres") private var hasChosenGenres: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Top section with profile view and status text
                HStack {
                    UserProfileView(userDisplayName: spotifyController.userDisplayName, userProfileImage: spotifyController.userProfileImage)
                    
                    Spacer() // Pushes status text to the right
                    
                    Text(isManualMode ? "Manual Mode" : "Dynamic Mode")
                        .fontWeight(.bold)
                        .padding(.trailing, 10) // Add padding from the right edge if needed
                }
                .padding(.top, 30.0) // Padding from the horizontal edges
                
                VStack {
                    if let currentTrackName = spotifyController.currentTrackName,
                       let currentTrackArtist = spotifyController.currentTrackArtist,
                       let currentTrackImage = spotifyController.currentTrackImage,
                       let currentTrackDuration = spotifyController.currentTrackDuration {
                        VStack {
                            Image(uiImage: currentTrackImage)
                                .resizable()
                                .frame(width: 250, height: 250)
                                .cornerRadius(8)
                                
                            VStack(alignment: .leading) {
                                Text(currentTrackName)
                                    .font(.title2)
                                Text(currentTrackArtist)
                                    .font(.headline)
                                    .foregroundColor(Color.gray)
                                
                                Text("\(currentTrackDuration / 60):\(String(format: "%02d", currentTrackDuration % 60))")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                if let tempo = spotifyController.currentTrackTempo {
                                    Text("\(tempo, specifier: "%.2f") BPM")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.trailing)
                                }
                                
                            }
                        }
                        .padding()
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            spotifyController.skipToPreviousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        Spacer()
                        Button(action: {
                            spotifyController.playPause()
                        }) {
                            Image(systemName: spotifyController.isPlaying ? "pause.fill" : "play.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .padding()
                                .background(Color.teal)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        Spacer()
                        Button(action: {
                            spotifyController.skipToNextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 15, height: 15)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        Spacer()
                    }
                    .onAppear {
                        spotifyController.authorize {
                            spotifyController.connect {
                                // Connection established
                            }
                        }
                    }
                    
                    VStack {
                        Text("Current Cadence")
                        Text("\(spotifyController.currentCadence * 60, specifier: "%.2f") steps/min")
                            .font(.title)
                        
                        Button(action: {
                            if isTracking {
                                spotifyController.stopTrackingCadence()
                            } else {
                                spotifyController.startTrackingCadence()
                            }
                            isTracking.toggle()
                        }) {
                            Text(isTracking ? "Stop Running" : "Start Running")
                                .font(.title)
                                .fontWeight(.heavy)
                                .padding()
                                .frame(width: 250.0, height: 60.0)
                                .background(isTracking ? Color.red : Color.teal)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .shadow(radius: 5)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationBarTitle("RunTempo", displayMode: .inline)
            .navigationBarItems(trailing: NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .imageScale(.large)
                    .foregroundColor(.teal)
            })
        }
        .onAppear {
            if !hasChosenGenres {
                hasChosenGenres = true
                // Automatically navigate to the settings view
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onOpenURL { url in
            spotifyController.setAccessToken(from: url)
        }
        .environmentObject(spotifyController)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
