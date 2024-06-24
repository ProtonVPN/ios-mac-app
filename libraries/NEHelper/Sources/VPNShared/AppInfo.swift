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
#if canImport(UIKit)
import UIKit
#endif

import Dependencies
import Domain
import Ergonomics


public protocol AppInfoFactory {
    func makeAppInfo(context: AppContext) -> AppInfo
}

extension AppInfoFactory {
    public func makeAppInfo() -> AppInfo {
        makeAppInfo(context: .default)
    }
}

public protocol AppInfo {
    var context: AppContext { get }
    var bundleInfoDictionary: [String: Any] { get }
    var clientInfoDictionary: [String: Any] { get }

    var processName: String { get }
    var modelName: String? { get }
    var osVersion: OperatingSystemVersion { get }
}

extension AppInfo {
    public var appVersion: String {
        clientId + "@" + bundleShortVersion
    }

    public var clientId: String {
        return clientInfoDictionary[context.clientIdKey] as? String ?? ""
    }

    public var bundleShortVersion: String {
        return bundleInfoDictionary["CFBundleShortVersionString"] as? String ?? ""
    }

    public var bundleVersion: String {
        return bundleInfoDictionary["CFBundleVersion"] as? String ?? ""
    }

    public var revisionInfo: String {
        return bundleInfoDictionary["RevisionInfo"] as? String ??
            "\(bundleShortVersion) (\(bundleVersion))"
    }

    private var platformName: String {
        #if os(iOS)
            return "iOS"
        #elseif os(macOS)
            return "Mac OS X"
        #elseif os(watchOS)
            return "watchOS"
        #elseif os(tvOS)
            return "tvOS"
        #else
            return "unknown"
        #endif
    }

    private var osVersionString: String {
        "\(platformName) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    private var osVersionAndModelString: String {
        var modelString: String = ""
        if let modelName = modelName {
            modelString = "; \(modelName)"
        }

        return "\(osVersionString)\(modelString)"
    }

    public var userAgent: String {
        "\(processName)/\(bundleShortVersion) (\(osVersionAndModelString))"
    }

    public var debugInfoString: String {
        "\(osVersionAndModelString). \(processName): \(revisionInfo)"
    }
}

public class AppInfoImplementation: AppInfo {
    public let bundleInfoDictionary: [String: Any]
    public let clientInfoDictionary: [String: Any]
    public let processName: String
    public let modelName: String?
    public let osVersion: OperatingSystemVersion
    public let context: AppContext

    public init(
        context: AppContext = .default,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        modelName: String? = nil
    ) {
        self.context = context
        processName = processInfo.processName
        osVersion = processInfo.operatingSystemVersion

        if let modelName = modelName {
            self.modelName = modelName
        } else {
            #if canImport(UIKit)
            self.modelName = UIDevice.current.modelName
            #elseif os(macOS)
            self.modelName = Host.current().localizedName ?? nil
            #endif
        }

        guard let file = bundle.path(forResource: "Client", ofType: "plist"),
              let clientDict = NSDictionary(contentsOfFile: file) as? [String: Any],
              let infoDict = bundle.infoDictionary else {
            clientInfoDictionary = [:]
            bundleInfoDictionary = [:]
            return
        }

        clientInfoDictionary = clientDict
        bundleInfoDictionary = infoDict
    }
}

public enum AppInfoKey: TestDependencyKey {
    public static var testValue: AppInfo {
        AppInfoImplementation(
            context: .default,
            bundle: .main,
            processInfo: .processInfo,
            modelName: nil
        )
    }
}

extension DependencyValues {
    public var appInfo: AppInfo {
        get { self[AppInfoKey.self] }
        set { self[AppInfoKey.self] = newValue }
    }
}
