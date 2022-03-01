//
//  Created on 2022-02-25.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
#if os(iOS)
import UIKit
#endif

class ExtensionAPIRequest {

    let apiUrl = "https://api.protonvpn.ch/"
    let config = URLSessionConfiguration.default
    lazy var session = URLSession(configuration: config)

    func initialRequest(endpoint: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(apiUrl)\(endpoint)")!)

        // Headers
        request.setValue(appVersion, forHTTPHeaderField: "x-pm-appversion")
        request.setValue("3", forHTTPHeaderField: "x-pm-apiversion")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.protonmail.v1+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        return request
    }

    private var userAgent: String {
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

    private var bundleShortVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var bundleVersion: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    private var appVersion: String {
        return clientId + "_" + bundleShortVersion
    }

    private var clientId: String {
        return clientDictionary.object(forKey: "Id") as? String ?? ""
    }

    private var clientDictionary: NSDictionary {
        guard let file = Bundle.main.path(forResource: "Client", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: file) else {
            return NSDictionary()
        }
        return dict
    }

}
