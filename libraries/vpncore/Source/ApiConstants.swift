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
import PMNetworking
#if os(iOS)
import UIKit
#endif

public struct ApiConstants {
    // swiftlint:disable force_try
    internal static var doh = try! DoHVPN(apiHost: "")
    // swiftlint:enable force_try

    public static var apiHost: String = "" {
        didSet {
            // swiftlint:disable force_try
            doh = try! DoHVPN(apiHost: apiHost)
            // swiftlint:enable force_try
        }
    }

    public static var baseURL: String {
        return doh.defaultHost
    }
    
    public static var liveURL: String {
        return doh.liveURL
    }

    public static var captchaHost: String {
        return doh.captchaHost
    }

    internal static var statusURL: String {
        return doh.statusHost
    }
    
    public static var baseHost: String {
        return doh.defaultHost.domainWithoutPathAndProtocol
    }

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
    
    static var userAgent: String {
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

#if os(iOS)
extension UIDevice {
    
    /// Get device model name
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
}
#endif
