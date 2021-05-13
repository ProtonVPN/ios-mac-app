//
//  OpenVPNTunnelProvider+Configuration.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 10/23/17.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import NetworkExtension
import SwiftyBeaver

private let log = SwiftyBeaver.self

extension OpenVPNTunnelProvider {
    private struct ExtraKeys {
        static let appGroup = "appGroup"
    }

    // MARK: Configuration
    
    /// The way to create a `OpenVPNTunnelProvider.Configuration` object for the tunnel profile.
    public struct ConfigurationBuilder {

        /// :nodoc:
        public static let defaults = Configuration(
            sessionConfiguration: OpenVPN.ConfigurationBuilder().build(),
            prefersResolvedAddresses: false,
            resolvedAddresses: nil,
            shouldDebug: false,
            debugLogFormat: nil,
            masksPrivateData: true,
            versionIdentifier: nil
        )
        
        /// The session configuration.
        public var sessionConfiguration: OpenVPN.Configuration
        
        /// Prefers resolved addresses over DNS resolution. `resolvedAddresses` must be set and non-empty. Default is `false`.
        ///
        /// - Seealso: `fallbackServerAddresses`
        public var prefersResolvedAddresses: Bool
        
        /// Resolved addresses in case DNS fails or `prefersResolvedAddresses` is `true` (IPv4 only).
        public var resolvedAddresses: [String]?

        /// Optional version identifier about the client pushed to server in peer-info as `IV_UI_VER`.
        public var versionIdentifier: String?

        // MARK: Debugging
        
        /// Enables debugging.
        public var shouldDebug: Bool
        
        /// Optional debug log format (SwiftyBeaver format).
        public var debugLogFormat: String?
        
        /// Mask private data in debug log (default is `true`).
        public var masksPrivateData: Bool?
        
        // MARK: Building
        
        /**
         Default initializer.
         
         - Parameter ca: The CA certificate.
         */
        public init(sessionConfiguration: OpenVPN.Configuration) {
            self.sessionConfiguration = sessionConfiguration
            prefersResolvedAddresses = ConfigurationBuilder.defaults.prefersResolvedAddresses
            resolvedAddresses = nil
            shouldDebug = ConfigurationBuilder.defaults.shouldDebug
            debugLogFormat = ConfigurationBuilder.defaults.debugLogFormat
            masksPrivateData = ConfigurationBuilder.defaults.masksPrivateData
            versionIdentifier = ConfigurationBuilder.defaults.versionIdentifier
        }
        
        /**
         Builds a `OpenVPNTunnelProvider.Configuration` object that will connect to the provided endpoint.
         
         - Returns: A `OpenVPNTunnelProvider.Configuration` object with this builder and the additional method parameters.
         */
        public func build() -> Configuration {
            return Configuration(
                sessionConfiguration: sessionConfiguration,
                prefersResolvedAddresses: prefersResolvedAddresses,
                resolvedAddresses: resolvedAddresses,
                shouldDebug: shouldDebug,
                debugLogFormat: shouldDebug ? debugLogFormat : nil,
                masksPrivateData: masksPrivateData,
                versionIdentifier: versionIdentifier
            )
        }
    }
    
    /// Offers a bridge between the abstract `OpenVPNTunnelProvider.ConfigurationBuilder` and a concrete `NETunnelProviderProtocol` profile.
    public struct Configuration: Codable {
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.sessionConfiguration`
        public let sessionConfiguration: OpenVPN.Configuration
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.prefersResolvedAddresses`
        public let prefersResolvedAddresses: Bool
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.resolvedAddresses`
        public let resolvedAddresses: [String]?

        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.shouldDebug`
        public let shouldDebug: Bool
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.debugLogFormat`
        public let debugLogFormat: String?
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.masksPrivateData`
        public let masksPrivateData: Bool?

        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.versionIdentifier`
        public let versionIdentifier: String?

        // MARK: Shortcuts

        static let debugLogFilename = "debug.log"

        static let lastErrorKey = "TunnelKitLastError"

        fileprivate static let dataCountKey = "TunnelKitDataCount"
        
        /**
         Returns the URL of the latest debug log.

         - Parameter in: The app group where to locate the log file.
         - Returns: The URL of the debug log, if any.
         */
        public func urlForLog(in appGroup: String) -> URL? {
            guard shouldDebug else {
                return nil
            }
            guard let parentURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                return nil
            }
            return parentURL.appendingPathComponent(Configuration.debugLogFilename)
        }

        /**
         Returns the content of the latest debug log.
         
         - Parameter in: The app group where to locate the log file.
         - Returns: The content of the debug log, if any.
         */
        public func existingLog(in appGroup: String) -> String? {
            guard let url = urlForLog(in: appGroup) else {
                return nil
            }
            return try? String(contentsOf: url)
        }
        
        /**
         Returns the last error reported by the tunnel, if any.
         
         - Parameter in: The app group where to locate the error key.
         - Returns: The last tunnel error, if any.
         */
        public func lastError(in appGroup: String) -> ProviderError? {
            guard let rawValue = UserDefaults(suiteName: appGroup)?.string(forKey: Configuration.lastErrorKey) else {
                return nil
            }
            return ProviderError(rawValue: rawValue)
        }

        /**
         Clear the last error status.
         
         - Parameter in: The app group where to locate the error key.
         */
        public func clearLastError(in appGroup: String) {
            UserDefaults(suiteName: appGroup)?.removeObject(forKey: Configuration.lastErrorKey)
        }
        
        /**
         Returns the most recent (received, sent) count in bytes.
         
         - Parameter in: The app group where to locate the count pair.
         - Returns: The bytes count pair, if any.
         */
        public func dataCount(in appGroup: String) -> (Int, Int)? {
            guard let rawValue = UserDefaults(suiteName: appGroup)?.dataCountArray else {
                return nil
            }
            guard rawValue.count == 2 else {
                return nil
            }
            return (rawValue[0], rawValue[1])
        }
        
        // MARK: API
        
        /**
         Parses the app group from a provider configuration map.
         
         - Parameter from: The map to parse.
         - Returns: The parsed app group.
         - Throws: `ProviderError.configuration` if `providerConfiguration` does not contain an app group.
         */
        public static func appGroup(from providerConfiguration: [String: Any]) throws -> String {
            guard let appGroup = providerConfiguration[ExtraKeys.appGroup] as? String else {
                throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(ExtraKeys.appGroup)]")
            }
            return appGroup
        }
        
        /**
         Parses a new `OpenVPNTunnelProvider.Configuration` object from a provider configuration map.
         
         - Parameter from: The map to parse.
         - Returns: The parsed `OpenVPNTunnelProvider.Configuration` object.
         - Throws: `ProviderError.configuration` if `providerConfiguration` is incomplete.
         */
        public static func parsed(from providerConfiguration: [String: Any]) throws -> Configuration {
            let cfg = try fromDictionary(OpenVPNTunnelProvider.Configuration.self, providerConfiguration)
            guard !cfg.prefersResolvedAddresses || !(cfg.resolvedAddresses?.isEmpty ?? true) else {
                throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[prefersResolvedAddresses] is true but no [resolvedAddresses]")
            }
            return cfg
        }

        /**
         Returns a dictionary representation of this configuration for use with `NETunnelProviderProtocol.providerConfiguration`.

         - Parameter appGroup: The name of the app group in which the tunnel extension lives in.
         - Returns: The dictionary representation of `self`.
         */
        public func generatedProviderConfiguration(appGroup: String) -> [String: Any] {
            do {
                var dict = try asDictionary()
                dict[ExtraKeys.appGroup] = appGroup
                return dict
            } catch let e {
                log.error("Unable to encode OpenVPN.Configuration: \(e)")
            }
            return [:]
        }
        
        /**
         Generates a `NETunnelProviderProtocol` from this configuration.
         
         - Parameter bundleIdentifier: The provider bundle identifier required to locate the tunnel extension.
         - Parameter appGroup: The name of the app group in which the tunnel extension lives in.
         - Parameter context: The keychain context where to look for the password reference.
         - Parameter username: The username to authenticate with.
         - Returns: The generated `NETunnelProviderProtocol` object.
         - Throws: `ProviderError.credentials` if unable to store `credentials.password` to the `appGroup` keychain.
         */
        public func generatedTunnelProtocol(
            withBundleIdentifier bundleIdentifier: String,
            appGroup: String,
            context: String,
            username: String?) throws -> NETunnelProviderProtocol {
            
            let protocolConfiguration = NETunnelProviderProtocol()
            let keychain = Keychain(group: appGroup)

            protocolConfiguration.providerBundleIdentifier = bundleIdentifier
            protocolConfiguration.serverAddress = sessionConfiguration.hostname ?? resolvedAddresses?.first
            if let username = username {
                protocolConfiguration.username = username
                protocolConfiguration.passwordReference = try? keychain.passwordReference(for: username, context: context)
            }
            protocolConfiguration.providerConfiguration = generatedProviderConfiguration(appGroup: appGroup)
            
            return protocolConfiguration
        }
        
        func print(appVersion: String?) {
            if let appVersion = appVersion {
                log.info("App version: \(appVersion)")
            }
            sessionConfiguration.print()
            log.info("\tDebug: \(shouldDebug)")
            log.info("\tMasks private data: \(masksPrivateData ?? true)")
        }
    }
}

// MARK: Modification

extension OpenVPNTunnelProvider.Configuration {
    
    /**
     Returns a `OpenVPNTunnelProvider.ConfigurationBuilder` to use this configuration as a starting point for a new one.
     
     - Returns: An editable `OpenVPNTunnelProvider.ConfigurationBuilder` initialized with this configuration.
     */
    public func builder() -> OpenVPNTunnelProvider.ConfigurationBuilder {
        var builder = OpenVPNTunnelProvider.ConfigurationBuilder(sessionConfiguration: sessionConfiguration)
        builder.prefersResolvedAddresses = prefersResolvedAddresses
        builder.resolvedAddresses = resolvedAddresses
        builder.shouldDebug = shouldDebug
        builder.debugLogFormat = debugLogFormat
        builder.masksPrivateData = masksPrivateData
        builder.versionIdentifier = versionIdentifier
        return builder
    }
}

/// :nodoc:
public extension UserDefaults {
    @objc var dataCountArray: [Int]? {
        get {
            return array(forKey: OpenVPNTunnelProvider.Configuration.dataCountKey) as? [Int]
        }
        set {
            set(newValue, forKey: OpenVPNTunnelProvider.Configuration.dataCountKey)
        }
    }
    
    func removeDataCountArray() {
        removeObject(forKey: OpenVPNTunnelProvider.Configuration.dataCountKey)
    }
}
