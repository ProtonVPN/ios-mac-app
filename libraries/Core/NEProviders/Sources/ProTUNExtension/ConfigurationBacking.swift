//
//  Created on 10/07/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ConnectionShared
import Foundation
import LocalAgent
import NetworkExtension
import OSLog

/// The mutable provider configuration a ``ConfigurationStore`` transaction operates on.
struct LoadedConfiguration {
    let providerProtocol: NETunnelProviderProtocol
    var isOnDemandEnabled: Bool?

    /// The OS-enforced properties the app mirrors into the real NE preferences.
    var managedConfiguration: ManagedConfiguration {
        #if os(tvOS)
            let includeAll = false
            let excludeLocal = false
        #else
            let includeAll = providerProtocol.includeAllNetworks
            let excludeLocal = providerProtocol.excludeLocalNetworks
        #endif
        return ManagedConfiguration(
            includeAllNetworks: includeAll,
            excludeLocalNetworks: excludeLocal,
            isOnDemandEnabled: isOnDemandEnabled,
            requestId: providerProtocol.requestId
        )
    }
}

/// Where ``ConfigurationStore`` reads and writes the provider configuration.
enum ConfigurationBacking: Sendable {
    static var backing: ConfigurationBacking {
        #if os(macOS)
            let directory = (try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? FileManager.default.temporaryDirectory
            return .custom(url: directory.appendingPathComponent("ProTUNConfiguration.plist"))
        #else
            return .networkExtension
        #endif
    }

    /// Using the NetworkExtension framework (iOS/tvOS)
    ///
    /// For platforms where the extension shares the user's context
    case networkExtension
    /// Using a dedicated file at specific URL
    ///
    /// For platforms with system extensions (root), having no access to per-user NE preferences.
    case custom(url: URL)

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}

extension ConfigurationBacking {
    /// `fallback` provides a base configuration when the custom store has nothing persisted yet (first run). It's the
    /// configuration the system started the provider with, which the store then becomes the source of truth for.
    func load(fallback: @autoclosure () -> NETunnelProviderProtocol? = nil) async throws(ConfigurationUpdateError) -> LoadedConfiguration {
        switch self {
        case .networkExtension:
            let manager = try await Self.loadManager()
            guard let config = manager.protocolConfiguration as? NETunnelProviderProtocol else {
                throw .badConfiguration
            }
            return LoadedConfiguration(providerProtocol: config, isOnDemandEnabled: manager.isOnDemandEnabled)

        case let .custom(url):
            return try CustomConfigurationPlist(loadingFrom: url, fallback: fallback()).configuration
        }
    }

    func save(_ configuration: LoadedConfiguration) async throws(ConfigurationUpdateError) {
        switch self {
        case .networkExtension:
            let manager = try await Self.loadManager()
            manager.protocolConfiguration = configuration.providerProtocol
            if let onDemand = configuration.isOnDemandEnabled {
                manager.isOnDemandEnabled = onDemand
            }
            do {
                try await manager.saveToPreferences()
            } catch {
                Logger.adapter.error("Unable to save tunnel configuration: \(error, privacy: .public)")
                throw .couldntSave
            }

        case let .custom(url):
            try CustomConfigurationPlist(configuration).write(to: url)
        }
    }

    #if os(macOS)
        /// Deletes any persisted config so it can't leak into another provider session.
        func clear() throws(ConfigurationUpdateError) {
            guard case let .custom(url) = self else {
                assertionFailure("Clear operation should be performed only on custom backing stores")
                return
            }
            do {
                try FileManager.default.removeItem(at: url)
                Logger.adapter.info("Cleared custom configuration store")
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                return
            } catch {
                Logger.adapter.error("Unable to clear custom configuration store: \(error, privacy: .public)")
                throw .couldntSave
            }
        }
    #endif
}

// MARK: - NetworkExtension backing

private extension ConfigurationBacking {
    static func loadManager() async throws(ConfigurationUpdateError) -> NETunnelProviderManager {
        let managers: [NETunnelProviderManager]
        do {
            managers = try await NETunnelProviderManager.loadAllFromPreferences()
        } catch {
            Logger.adapter.error("Failed to load ProTUN manager: \(error, privacy: .public)")
            throw .missingManager
        }
        guard let manager = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Bundle.main.bundleIdentifier
        }) else {
            throw .missingManager
        }
        return manager
    }
}

// MARK: - Custom file backing

/// Packs a ``LoadedConfiguration`` to and from the property list the custom backing persists on disk.
private struct CustomConfigurationPlist {
    private enum Key: String {
        case providerConfiguration
        case includeAllNetworks
        case excludeLocalNetworks
        case isOnDemandEnabled
        case serverAddress
        case providerBundleIdentifier
    }

    let configuration: LoadedConfiguration

    init(_ configuration: LoadedConfiguration) {
        self.configuration = configuration
    }

    init(loadingFrom url: URL, fallback: @autoclosure () -> NETunnelProviderProtocol?) throws(ConfigurationUpdateError) {
        guard let data = try? Data(contentsOf: url) else {
            guard let fallback = fallback() else { throw .missingManager }
            self.configuration = LoadedConfiguration(providerProtocol: fallback, isOnDemandEnabled: nil)
            return
        }
        do {
            let dict = try PropertyListSerialization.propertyList(from: data, format: nil)
            guard let dict = dict as? [String: Any] else {
                Logger.adapter.error("Custom configuration is invalid, got: \(dict as? NSObject, privacy: .public)")
                throw ConfigurationUpdateError.badConfiguration
            }
            self.configuration = Self.decode(dict)
        } catch {
            Logger.adapter.error("Failed to decode custom configuration store: \(error, privacy: .public)")
            throw .badConfiguration
        }
    }

    func write(to url: URL) throws(ConfigurationUpdateError) {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: encoded(), format: .binary, options: 0)
            try data.write(to: url, options: .atomic)
        } catch {
            Logger.adapter.error("Unable to write custom configuration store: \(error, privacy: .public)")
            throw .couldntSave
        }
    }

    private static func decode(_ dict: [String: Any]) -> LoadedConfiguration {
        let proto = NETunnelProviderProtocol()
        proto.providerConfiguration = dict[Key.providerConfiguration.rawValue] as? [String: Any]
        proto.serverAddress = dict[Key.serverAddress.rawValue] as? String
        proto.providerBundleIdentifier = dict[Key.providerBundleIdentifier.rawValue] as? String
        #if !os(tvOS)
            proto.includeAllNetworks = dict[Key.includeAllNetworks.rawValue] as? Bool ?? false
            proto.excludeLocalNetworks = dict[Key.excludeLocalNetworks.rawValue] as? Bool ?? false
        #endif
        return LoadedConfiguration(providerProtocol: proto, isOnDemandEnabled: dict[Key.isOnDemandEnabled.rawValue] as? Bool)
    }

    private func encoded() -> [String: Any] {
        let proto = configuration.providerProtocol
        var dict: [String: Any] = [:]
        dict[Key.providerConfiguration.rawValue] = proto.providerConfiguration
        dict[Key.serverAddress.rawValue] = proto.serverAddress
        dict[Key.providerBundleIdentifier.rawValue] = proto.providerBundleIdentifier
        #if !os(tvOS)
            dict[Key.includeAllNetworks.rawValue] = proto.includeAllNetworks
            dict[Key.excludeLocalNetworks.rawValue] = proto.excludeLocalNetworks
        #endif
        if let onDemand = configuration.isOnDemandEnabled {
            dict[Key.isOnDemandEnabled.rawValue] = onDemand
        }
        return dict
    }
}
