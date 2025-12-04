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

// MARK: - AppInfo Struct

public struct AppInfo: Sendable {
    public var context: @Sendable () -> AppContext
    public var bundleInfoDictionary: @Sendable () -> [String: Any]
    public var clientInfoDictionary: @Sendable () -> [String: Any]
    public var processName: @Sendable () -> String
    public var modelName: @Sendable () -> String?
    public var osVersion: @Sendable () -> OperatingSystemVersion

    public init(
        context: @escaping @Sendable () -> AppContext,
        bundleInfoDictionary: @escaping @Sendable () -> [String: Any],
        clientInfoDictionary: @escaping @Sendable () -> [String: Any],
        processName: @escaping @Sendable () -> String,
        modelName: @escaping @Sendable () -> String?,
        osVersion: @escaping @Sendable () -> OperatingSystemVersion
    ) {
        self.context = context
        self.bundleInfoDictionary = bundleInfoDictionary
        self.clientInfoDictionary = clientInfoDictionary
        self.processName = processName
        self.modelName = modelName
        self.osVersion = osVersion
    }
}

// MARK: - Computed Properties

public extension AppInfo {
    var appVersion: String {
        clientId + "@" + bundleShortVersion
    }

    func clientId(forContext specificContext: AppContext) -> String {
        clientInfoDictionary()[specificContext.clientIdKey] as? String ?? ""
    }

    var clientId: String {
        clientId(forContext: context())
    }

    var bundleShortVersion: String {
        bundleInfoDictionary()["CFBundleShortVersionString"] as? String ?? "0"
    }

    var bundleVersion: String {
        bundleInfoDictionary()["CFBundleVersion"] as? String ?? "0"
    }

    var product: String {
        bundleInfoDictionary()["CFBundleName"] as? String ?? ""
    }

    var identifier: String? {
        bundleInfoDictionary()["CFBundleIdentifier"] as? String
    }

    var revisionInfo: String {
        bundleInfoDictionary()["RevisionInfo"] as? String ??
            "\(bundleShortVersion) (\(bundleVersion))"
    }

    var appStoreId: String? {
        bundleInfoDictionary()["AppStoreID"] as? String
    }

    var appIdentifierPrefix: String {
        bundleInfoDictionary()["AppIdentifierPrefix"] as? String ?? ""
    }

    package var platformName: String {
        #if os(iOS)
            return "iOS"
        #elseif os(macOS)
            return "macOS"
        #elseif os(watchOS)
            return "watchOS"
        #elseif os(tvOS)
            return "tvOS"
        #else
            return "unknown"
        #endif
    }

    package var osVersionString: String {
        let version = osVersion()
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private var osVersionAndModelString: String {
        var modelString = ""
        if let model = modelName() {
            modelString = "; \(model)"
        }

        return "\(platformName) \(osVersionString)\(modelString)"
    }

    var userAgent: String {
        "\(processName())/\(bundleShortVersion) (\(osVersionAndModelString))"
    }

    var debugInfoString: String {
        "\(osVersionAndModelString). \(processName()): \(revisionInfo)"
    }
}

public extension AppInfo {
    static func live(
        context: AppContext,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        modelName: String? = FileLogContent.modelName
    ) -> AppInfo {
        let clientDict: [String: Any]
        let infoDict: [String: Any]

        if let file = bundle.path(forResource: "Client", ofType: "plist"),
           let clientDictionary = NSDictionary(contentsOfFile: file) as? [String: Any],
           let bundleInfoDict = bundle.infoDictionary {
            clientDict = clientDictionary
            infoDict = bundleInfoDict
        } else {
            clientDict = [:]
            infoDict = [:]
        }

        return AppInfo(
            context: { context },
            bundleInfoDictionary: { infoDict },
            clientInfoDictionary: { clientDict },
            processName: { processInfo.processName },
            modelName: { modelName },
            osVersion: { processInfo.operatingSystemVersion }
        )
    }
}

// MARK: - Dependency Key

public enum AppInfoKey: TestDependencyKey {
    public static var testValue: AppInfo {
        .live(
            context: .mainApp,
            bundle: .main,
            processInfo: .processInfo,
            modelName: nil
        )
    }
}

public extension DependencyValues {
    var appInfo: AppInfo {
        get { self[AppInfoKey.self] }
        set { self[AppInfoKey.self] = newValue }
    }
}
