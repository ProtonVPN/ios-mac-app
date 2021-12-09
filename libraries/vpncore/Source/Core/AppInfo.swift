//
//  Created on 09.12.2021.
//
//  Copyright (c) 2021 Proton AG
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
import ProtonCore_Doh

public protocol AppInfoFactory {
    func makeAppInfo() -> AppInfo
}

public protocol AppInfo {
    var clientId: String { get }
    var bundleShortVersion: String { get }
    var bundleVersion: String { get }
    var appVersion: String { get }
    var userAgent: String { get }
}

public class AppInfoImplementation: AppInfo {
    private let clientDictionary: NSDictionary

    public init() {
        guard let file = Bundle.main.path(forResource: "Client", ofType: "plist"), let dict = NSDictionary(contentsOfFile: file) else {
            clientDictionary = NSDictionary()
            return
        }

        clientDictionary = dict
    }

    public var clientId: String {
        return clientDictionary.object(forKey: "Id") as? String ?? ""
    }

    public var bundleShortVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    public var bundleVersion: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    public var appVersion: String {
        return clientId + "_" + bundleShortVersion
    }

    public var userAgent: String {
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
