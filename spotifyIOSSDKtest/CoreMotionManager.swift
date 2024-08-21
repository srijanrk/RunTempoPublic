//
//  CoreMotionManager.swift
//  spotifyIOSSDKtest
//
//  Created by Srijan Kunta on 7/20/24.
//

import Foundation
import CoreMotion
import Combine

class CoreMotionManager: ObservableObject {
    private let pedometer = CMPedometer()
    
    @Published var currentCadence: Double = 0.0
    
    func startUpdating() {
        guard CMPedometer.isCadenceAvailable() else {
            print("Cadence data is not available.")
            return
        }
        
        pedometer.startUpdates(from: Date()) { [weak self] (pedometerData, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            if let pedData = pedometerData, let cadence = pedData.currentCadence {
                DispatchQueue.main.async {
                    self?.currentCadence = cadence.doubleValue
                }
            }
        }
    }
    
    func stopUpdating() {
        pedometer.stopUpdates()
    }
    
    func updateCadence() {
        guard CMPedometer.isCadenceAvailable() else {
            print("Cadence data is not available.")
            return
        }
        
        pedometer.queryPedometerData(from: Date().addingTimeInterval(-8), to: Date()) { [weak self] (pedometerData, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            if let pedData = pedometerData, let cadence = pedData.currentCadence {
                DispatchQueue.main.async {
                    self?.currentCadence = cadence.doubleValue
                }
            }
        }
    }
}
