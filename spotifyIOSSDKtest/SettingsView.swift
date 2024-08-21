//
//  SettingsView.swift
//  spotifyIOSSDKtest
//
//  Created by Srijan Kunta on 8/12/24.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage("isManualMode") private var isManualMode: Bool = false  // Track the app mode
    @AppStorage("manualTempo") private var manualTempo: Double = 160.0  // Store the manual tempo
    
    @State private var selectedGenres: [String] = UserDefaults.standard.stringArray(forKey: "selectedGenres") ?? []  // Manage selected genres locally
    
    let availableGenres = [
        "acoustic", "afrobeat", "alt-rock", "alternative", "ambient", "anime", "black-metal", "bluegrass", "blues", "bossanova", "brazil", "breakbeat", "british", "cantopop", "chicago-house", "children", "chill", "classical", "club", "comedy", "country", "dance", "dancehall", "death-metal", "deep-house", "detroit-techno", "disco", "disney", "drum-and-bass", "dub", "dubstep", "edm", "electro", "electronic", "emo", "folk", "forro", "french", "funk", "garage", "german", "gospel", "goth", "grindcore", "groove", "grunge", "guitar", "happy", "hard-rock", "hardcore", "hardstyle", "heavy-metal", "hip-hop", "holidays", "honky-tonk", "house", "idm", "indian", "indie", "indie-pop", "industrial", "iranian", "j-dance", "j-idol", "j-pop", "j-rock", "jazz", "k-pop", "kids", "latin", "latino", "malay", "mandopop", "metal", "metal-misc", "metalcore", "minimal-techno", "movies", "mpb", "new-age", "new-release", "opera", "pagode", "party", "philippines-opm", "piano", "pop", "pop-film", "post-dubstep", "power-pop", "progressive-house", "psych-rock", "punk", "punk-rock", "r-n-b", "rainy-day", "reggae", "reggaeton", "road-trip", "rock", "rock-n-roll", "rockabilly", "romance", "sad", "salsa", "samba", "sertanejo", "show-tunes", "singer-songwriter", "ska", "sleep", "songwriter", "soul", "soundtracks", "spanish", "study", "summer", "swedish", "synth-pop", "tango", "techno", "trance", "trip-hop", "turkish", "work-out", "world-music"
    ]
    
    var body: some View {
        Form {
            Section(header: Text("Mode Selection")) {
                Toggle(isOn: $isManualMode) {
                    Text("Manual Tempo Mode")
                }
                
                if isManualMode {
                    HStack {
                        Text("Tempo (BPM):")
                        Slider(value: $manualTempo, in: 60...200, step: 1)
                        Text("\(Int(manualTempo)) BPM")
                    }
                }
            }

            Section(header: Text("Selected Genres")) {
                if selectedGenres.isEmpty {
                    Text("No genres selected")
                        .foregroundColor(.gray)
                } else {
                    ForEach(selectedGenres, id: \.self) { genre in
                        Text(genre)
                    }
                }
            }

            
            Section(header: Text("Choose Preferred Genres")) {
                List(availableGenres, id: \.self) { genre in
                    MultipleSelectionRow(title: genre, isSelected: selectedGenres.contains(genre)) {
                        if selectedGenres.contains(genre) {
                            selectedGenres.removeAll { $0 == genre }
                        } else if selectedGenres.count < 5 {
                            selectedGenres.append(genre)
                        }
                        UserDefaults.standard.set(selectedGenres, forKey: "selectedGenres")  // Update UserDefaults
                    }
                }
            }


            Section(header: Text("About")) {
                Text("Version 1.0")
                Text("Developed by Srijan Kunta")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MultipleSelectionRow: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack {
                Text(self.title)
                if self.isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
