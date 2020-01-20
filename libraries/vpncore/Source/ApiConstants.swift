//
//  ApiConstants.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public struct ApiConstants {
    
    public static let liveURL = "https://api.protonvpn.ch" // do not change to development url due to IAP restriction
    
    private static var propertiesManager = PropertiesManager()
    public static var baseURL: String {
        #if RELEASE
        return liveURL
        #endif
        
        return propertiesManager.apiEndpoint ?? liveURL
    }
    
    public static let baseHost = "api.protonvpn.ch"
    public static let captchaHost = "secure.protonmail.com"
    
    internal static let statusURL = "http://protonstatus.com"
    internal static let contentType = "application/json;charset=utf-8"
    internal static let mediaType = "application/vnd.protonmail.v1+json"
    public static let defaultRequestTimeout: TimeInterval = 30
    
    public static var clientDictionary: NSDictionary {
        guard let file = Bundle.main.path(forResource: "Client", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: file) else {
            return NSDictionary()
        }
        
        return dict
    }
    
    public static var clientId: String {
        return clientDictionary.object(forKey: "Id") as? String ?? ""
    }
    
    public static var clientSecret: String {
        return clientDictionary.object(forKey: "Secret") as? String ?? ""
    }
    
    public static var bundleShortVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    public static var bundleVersion: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
    
    static var appVersion: String {
        return clientId + "_" + bundleShortVersion
    }
}
