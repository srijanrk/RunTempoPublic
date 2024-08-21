//
//  Environment.swift
//  spotifyIOSSDKtest
//
//  Created by Srijan Kunta on 8/19/24.
//

import Foundation

public enum Environment {
    enum Keys {
        static let apiKey = "SPOTIFY_CLIENT_ID"
        static let baseUrl = "SPOTIFY_REDIRECT_URL"
    }
    
    //getting plist
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary
        else {
            fatalError("plist file not found")
        }
        return dict
    }()
    
    //get apiKey and baseUrl from plist
    static let baseURL: String = {
        guard let baseURLString = Environment.infoDictionary[Keys.baseUrl] as? String
        else {
            fatalError("Base URL not set in plist")
        }
        return baseURLString.replacingOccurrences(of: "\\", with: "")
    }()
    
    static let apiKey: String = {
        guard let apiKeyString = Environment.infoDictionary[Keys.apiKey] as? String
        else {
            fatalError("API Key not set in plist")
        }
        return apiKeyString
    }()
}
