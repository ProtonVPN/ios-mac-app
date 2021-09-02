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
import ProtonCore_Doh

public struct ApiConstants {
    // swiftlint:disable force_try
    public static var doh = try! DoHVPN(apiHost: "")
    // swiftlint:enable force_try

    public static var apiHost: String = "" {
        didSet {
            // swiftlint:disable force_try
            doh = try! DoHVPN(apiHost: apiHost)
            // swiftlint:enable force_try
        }
    }
    
    public static var liveURL: String {
        return doh.liveURL
    }
    
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
    
    public static var appVersion: String {
        return clientId + "_" + bundleShortVersion
    }
    
    public static var userAgent: String {
        let info = ProcessInfo()
        let osVersion = info.operatingSystemVersion
        let processName = info.processName
        var os = "unknown"
        var device = ""
        #if os(iOS)
            os = "iOS"
            device = "; \(UIDevice.current.modelName)"
        #elseif os(macOS)
            os = "Mac OS X"
        #elseif os(watchOS)
            os = "watchOS"
        #elseif os(tvOS)
            os = "tvOS"
        #endif
        
        return "\(processName)/\(bundleShortVersion) (\(os) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)\(device))"
    }
    
}
