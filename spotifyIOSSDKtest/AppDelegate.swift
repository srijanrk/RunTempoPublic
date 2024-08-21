//
//  AppDelegate.swift
//  spotifyIOSSDKtest
//
//  Created by Srijan Kunta on 8/12/24.
//

import Foundation
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {

    var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func applicationDidEnterBackground(_ application: UIApplication) {
        startBackgroundTask()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        endBackgroundTask()
    }

    func startBackgroundTask() {
        endBackgroundTask()  // End any existing background tasks before starting a new one

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SpotifyQueueUpdate") {
            // This block is called when the background task is about to be terminated by the system
            self.endBackgroundTask()
        }

        guard backgroundTask != .invalid else {
            return
        }

        DispatchQueue.global(qos: .background).async {
            self.runBackgroundTask()
        }
    }

    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    func runBackgroundTask() {
        // Example: Update cadence or manage the Spotify queue
        let startTime = Date()

        while UIApplication.shared.backgroundTimeRemaining > 1.0 {
            if Date().timeIntervalSince(startTime) > 25.0 {
                // End the task after 25 seconds to avoid termination
                break
            }

            // Perform the work you need to do in the background
            // Example: Fetch new song recommendations
            DispatchQueue.main.async {
                // Update UI or state if needed
            }

            // Add a small delay to prevent continuous looping without pause
            Thread.sleep(forTimeInterval: 1.0)
        }

        self.endBackgroundTask()
    }
}
