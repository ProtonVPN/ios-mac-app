//
//  OpenVPNTunnelProvider+Configuration.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 10/23/17.
//  Copyright (c) 2020 Davide De Rosa. All rights reserved.
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

    // MARK: Configuration
    
    /// The way to create a `OpenVPNTunnelProvider.Configuration` object for the tunnel profile.
    public struct ConfigurationBuilder {

        /// :nodoc:
        public static let defaults = Configuration(
            sessionConfiguration: OpenVPN.ConfigurationBuilder().build(),
            prefersResolvedAddresses: false,
            resolvedAddresses: nil,
            mtu: 1250,
            shouldDebug: false,
            debugLogFormat: nil,
            masksPrivateData: true
        )
        
        /// The session configuration.
        public var sessionConfiguration: OpenVPN.Configuration
        
        /// Prefers resolved addresses over DNS resolution. `resolvedAddresses` must be set and non-empty. Default is `false`.
        ///
        /// - Seealso: `fallbackServerAddresses`
        public var prefersResolvedAddresses: Bool
        
        /// Resolved addresses in case DNS fails or `prefersResolvedAddresses` is `true` (IPv4 only).
        public var resolvedAddresses: [String]?
        
        /// The MTU of the link.
        public var mtu: Int
        
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
            mtu = ConfigurationBuilder.defaults.mtu
            shouldDebug = ConfigurationBuilder.defaults.shouldDebug
            debugLogFormat = ConfigurationBuilder.defaults.debugLogFormat
            masksPrivateData = ConfigurationBuilder.defaults.masksPrivateData
        }
        
        fileprivate init(providerConfiguration: [String: Any]) throws {
            let S = Configuration.Keys.self

            sessionConfiguration = try OpenVPN.Configuration.with(providerConfiguration: providerConfiguration)
            prefersResolvedAddresses = providerConfiguration[S.prefersResolvedAddresses] as? Bool ?? ConfigurationBuilder.defaults.prefersResolvedAddresses
            resolvedAddresses = providerConfiguration[S.resolvedAddresses] as? [String]
            mtu = providerConfiguration[S.mtu] as? Int ?? ConfigurationBuilder.defaults.mtu
            shouldDebug = providerConfiguration[S.debug] as? Bool ?? ConfigurationBuilder.defaults.shouldDebug
            if shouldDebug {
                debugLogFormat = providerConfiguration[S.debugLogFormat] as? String
            }
            masksPrivateData = providerConfiguration[S.masksPrivateData] as? Bool ?? ConfigurationBuilder.defaults.masksPrivateData

            guard !prefersResolvedAddresses || !(resolvedAddresses?.isEmpty ?? true) else {
                throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(S.prefersResolvedAddresses)] is true but no [\(S.resolvedAddresses)]")
            }
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
                mtu: mtu,
                shouldDebug: shouldDebug,
                debugLogFormat: shouldDebug ? debugLogFormat : nil,
                masksPrivateData: masksPrivateData
            )
        }
    }
    
    /// Offers a bridge between the abstract `OpenVPNTunnelProvider.ConfigurationBuilder` and a concrete `NETunnelProviderProtocol` profile.
    public struct Configuration: Codable {
        struct Keys {
            static let appGroup = "AppGroup"
            
            // MARK: SessionConfiguration

            static let cipherAlgorithm = "CipherAlgorithm"
            
            static let digestAlgorithm = "DigestAlgorithm"
            
            static let compressionFraming = "CompressionFraming"
            
            static let compressionAlgorithm = "CompressionAlgorithm"
            
            static let ca = "CA"
            
            static let clientCertificate = "ClientCertificate"
            
            static let clientKey = "ClientKey"
            
            static let tlsWrap = "TLSWrap"

            static let tlsSecurityLevel = "TLSSecurityLevel"

            static let keepAlive = "KeepAlive"
            
            static let keepAliveTimeout = "KeepAliveTimeout"
            
            static let endpointProtocols = "EndpointProtocols"
            
            static let renegotiatesAfter = "RenegotiatesAfter"
            
            static let checksEKU = "ChecksEKU"
            
            static let checksSANHost = "checksSANHost"
            
            static let sanHost = "sanHost"
            
            static let randomizeEndpoint = "RandomizeEndpoint"
            
            static let usesPIAPatches = "UsesPIAPatches"
            
            static let dnsServers = "DNSServers"
            
            static let searchDomains = "SearchDomains"
            
            static let httpProxy = "HTTPProxy"
            
            static let httpsProxy = "HTTPSProxy"
            
            static let proxyAutoConfigurationURL = "ProxyAutoConfigurationURL"
            
            static let proxyBypassDomains = "ProxyBypassDomains"
            
            static let routingPolicies = "RoutingPolicies"
            
            // MARK: Customization

            static let prefersResolvedAddresses = "PrefersResolvedAddresses"
            
            static let resolvedAddresses = "ResolvedAddresses"
            
            static let mtu = "MTU"
            
            // MARK: Debugging
            
            static let debug = "Debug"
            
            static let debugLogFormat = "DebugLogFormat"

            static let masksPrivateData = "MasksPrivateData"
        }
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.sessionConfiguration`
        public let sessionConfiguration: OpenVPN.Configuration
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.prefersResolvedAddresses`
        public let prefersResolvedAddresses: Bool
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.resolvedAddresses`
        public let resolvedAddresses: [String]?

        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.mtu`
        public let mtu: Int
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.shouldDebug`
        public let shouldDebug: Bool
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.debugLogFormat`
        public let debugLogFormat: String?
        
        /// - Seealso: `OpenVPNTunnelProvider.ConfigurationBuilder.masksPrivateData`
        public let masksPrivateData: Bool?
        
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
            guard let appGroup = providerConfiguration[Keys.appGroup] as? String else {
                throw ProviderConfigurationError.parameter(name: "protocolConfiguration.providerConfiguration[\(Keys.appGroup)]")
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
            let builder = try ConfigurationBuilder(providerConfiguration: providerConfiguration)
            return builder.build()
        }
        
        /**
         Returns a dictionary representation of this configuration for use with `NETunnelProviderProtocol.providerConfiguration`.

         - Parameter appGroup: The name of the app group in which the tunnel extension lives in.
         - Returns: The dictionary representation of `self`.
         */
        public func generatedProviderConfiguration(appGroup: String) -> [String: Any] {
            let S = Keys.self
            
            guard let ca = sessionConfiguration.ca else {
                fatalError("No sessionConfiguration.ca set")
            }
            guard let endpointProtocols = sessionConfiguration.endpointProtocols else {
                fatalError("No sessionConfiguration.endpointProtocols set")
            }

            var dict: [String: Any] = [
                S.appGroup: appGroup,
                S.prefersResolvedAddresses: prefersResolvedAddresses,
                S.ca: ca.pem,
                S.endpointProtocols: endpointProtocols.map { $0.rawValue },
                S.mtu: mtu,
                S.debug: shouldDebug
            ]
            sessionConfiguration.store(to: &dict)
            if let resolvedAddresses = resolvedAddresses {
                dict[S.resolvedAddresses] = resolvedAddresses
            }
            if let debugLogFormat = debugLogFormat {
                dict[S.debugLogFormat] = debugLogFormat
            }
            if let masksPrivateData = masksPrivateData {
                dict[S.masksPrivateData] = masksPrivateData
            }
            return dict
        }
        
        /**
         Generates a `NETunnelProviderProtocol` from this configuration.
         
         - Parameter bundleIdentifier: The provider bundle identifier required to locate the tunnel extension.
         - Parameter appGroup: The name of the app group in which the tunnel extension lives in.
         - Parameter credentials: The optional credentials to authenticate with.
         - Returns: The generated `NETunnelProviderProtocol` object.
         - Throws: `ProviderError.credentials` if unable to store `credentials.password` to the `appGroup` keychain.
         */
        public func generatedTunnelProtocol(withBundleIdentifier bundleIdentifier: String, appGroup: String, credentials: OpenVPN.Credentials? = nil) throws -> NETunnelProviderProtocol {
            let protocolConfiguration = NETunnelProviderProtocol()
            
            protocolConfiguration.providerBundleIdentifier = bundleIdentifier
            protocolConfiguration.serverAddress = sessionConfiguration.hostname ?? resolvedAddresses?.first
            if let username = credentials?.username, let password = credentials?.password {
                let keychain = Keychain(group: appGroup)
                do {
                    try keychain.set(password: password, for: username, label: Bundle.main.bundleIdentifier)
                } catch _ {
                    throw ProviderConfigurationError.credentials(details: "keychain.set()")
                }
                protocolConfiguration.username = username
                protocolConfiguration.passwordReference = try? keychain.passwordReference(for: username)
            }
            protocolConfiguration.providerConfiguration = generatedProviderConfiguration(appGroup: appGroup)
            
            return protocolConfiguration
        }
        
        func print(appVersion: String?) {
            if let appVersion = appVersion {
                log.info("App version: \(appVersion)")
            }
            sessionConfiguration.print()
            log.info("\tMTU: \(mtu)")
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
        builder.mtu = mtu
        builder.shouldDebug = shouldDebug
        builder.debugLogFormat = debugLogFormat
        builder.masksPrivateData = masksPrivateData
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

// MARK: OpenVPN configuration

private extension OpenVPN.Configuration {
    static func with(providerConfiguration: [String: Any]) throws -> OpenVPN.Configuration {
        let S = OpenVPNTunnelProvider.Configuration.Keys.self
        let E = OpenVPNTunnelProvider.ProviderConfigurationError.self
        
        guard let caPEM = providerConfiguration[S.ca] as? String else {
            throw E.parameter(name: "protocolConfiguration.providerConfiguration[\(S.ca)]")
        }
        guard let endpointProtocolsStrings = providerConfiguration[S.endpointProtocols] as? [String], !endpointProtocolsStrings.isEmpty else {
            throw E.parameter(name: "protocolConfiguration.providerConfiguration[\(S.endpointProtocols)] is nil or empty")
        }

        var builder = OpenVPNTunnelProvider.ConfigurationBuilder.defaults.sessionConfiguration.builder()

        builder.ca = OpenVPN.CryptoContainer(pem: caPEM)
        builder.endpointProtocols = try endpointProtocolsStrings.map {
            guard let ep = EndpointProtocol(rawValue: $0) else {
                throw E.parameter(name: "protocolConfiguration.providerConfiguration[\(S.endpointProtocols)] has a badly formed element")
            }
            return ep
        }

        if let cipherAlgorithm = providerConfiguration[S.cipherAlgorithm] as? String {
            builder.cipher = OpenVPN.Cipher(rawValue: cipherAlgorithm)
        }
        if let digestAlgorithm = providerConfiguration[S.digestAlgorithm] as? String {
            builder.digest = OpenVPN.Digest(rawValue: digestAlgorithm)
        }
        if let compressionFramingValue = providerConfiguration[S.compressionFraming] as? Int, let compressionFraming = OpenVPN.CompressionFraming(rawValue: compressionFramingValue) {
            builder.compressionFraming = compressionFraming
        }
        if let compressionAlgorithmValue = providerConfiguration[S.compressionAlgorithm] as? Int, let compressionAlgorithm = OpenVPN.CompressionAlgorithm(rawValue: compressionAlgorithmValue) {
            builder.compressionAlgorithm = compressionAlgorithm
        }
        if let clientPEM = providerConfiguration[S.clientCertificate] as? String {
            guard let keyPEM = providerConfiguration[S.clientKey] as? String else {
                throw E.parameter(name: "protocolConfiguration.providerConfiguration[\(S.clientKey)]")
            }
            builder.clientCertificate = OpenVPN.CryptoContainer(pem: clientPEM)
            builder.clientKey = OpenVPN.CryptoContainer(pem: keyPEM)
        }
        if let tlsWrapData = providerConfiguration[S.tlsWrap] as? Data {
            do {
                builder.tlsWrap = try OpenVPN.TLSWrap.deserialized(tlsWrapData)
            } catch {
                throw E.parameter(name: "protocolConfiguration.providerConfiguration[\(S.tlsWrap)]")
            }
        }
        if let tlsSecurityLevel = providerConfiguration[S.tlsSecurityLevel] as? Int {
            builder.tlsSecurityLevel =  tlsSecurityLevel
        }
        if let keepAliveInterval = providerConfiguration[S.keepAlive] as? TimeInterval {
            builder.keepAliveInterval = keepAliveInterval
        }
        if let keepAliveTimeout = providerConfiguration[S.keepAliveTimeout] as? TimeInterval {
            builder.keepAliveTimeout = keepAliveTimeout
        }
        if let renegotiatesAfter = providerConfiguration[S.renegotiatesAfter] as? TimeInterval {
            builder.renegotiatesAfter = renegotiatesAfter
        }
        if let checksEKU = providerConfiguration[S.checksEKU] as? Bool {
            builder.checksEKU = checksEKU
        }
        if let checksSANHost = providerConfiguration[S.checksSANHost] as? Bool {
            builder.checksSANHost = checksSANHost
        }
        if let sanHost = providerConfiguration[S.sanHost] as? String {
            builder.sanHost = sanHost
        }
        if let randomizeEndpoint = providerConfiguration[S.randomizeEndpoint] as? Bool {
            builder.randomizeEndpoint = randomizeEndpoint
        }
        if let usesPIAPatches = providerConfiguration[S.usesPIAPatches] as? Bool {
            builder.usesPIAPatches = usesPIAPatches
        }
        if let dnsServers = providerConfiguration[S.dnsServers] as? [String] {
            builder.dnsServers = dnsServers
        }
        if let searchDomains = providerConfiguration[S.searchDomains] as? [String] {
            builder.searchDomains = searchDomains
        }
        if let proxyString = providerConfiguration[S.httpProxy] as? String {
            guard let proxy = Proxy(rawValue: proxyString) else {
                throw E.parameter(name: "protocolConfiguration.providerConfiguration[\(S.httpProxy)] has a badly formed element")
            }
            builder.httpProxy = proxy
        }
        if let proxyString = providerConfiguration[S.httpsProxy] as? String {
            guard let proxy = Proxy(rawValue: proxyString) else {
                throw E.parameter(name: "protocolConfiguration.providerConfiguration[\(S.httpsProxy)] has a badly formed element")
            }
            builder.httpsProxy = proxy
        }
        if let proxyAutoConfigurationURLString = providerConfiguration[S.proxyAutoConfigurationURL] as? String, let proxyAutoConfigurationURL = URL(string: proxyAutoConfigurationURLString) {
            builder.proxyAutoConfigurationURL = proxyAutoConfigurationURL
        }
        if let proxyBypassDomains = providerConfiguration[S.proxyBypassDomains] as? [String] {
            builder.proxyBypassDomains = proxyBypassDomains
        }
        if let routingPoliciesStrings = providerConfiguration[S.routingPolicies] as? [String] {
            builder.routingPolicies = try routingPoliciesStrings.map {
                guard let policy = OpenVPN.RoutingPolicy(rawValue: $0) else {
                    throw E.parameter(name: "protocolConfiguration.providerConfiguration[\(S.routingPolicies)] has a badly formed element")
                }
                return policy
            }
        }
        return builder.build()
    }
    
    func store(to dict: inout [String: Any]) {
        let S = OpenVPNTunnelProvider.Configuration.Keys.self

        if let cipher = cipher {
            dict[S.cipherAlgorithm] = cipher.rawValue
        }
        if let digest = digest {
            dict[S.digestAlgorithm] = digest.rawValue
        }
        if let compressionFraming = compressionFraming {
            dict[S.compressionFraming] = compressionFraming.rawValue
        }
        if let compressionAlgorithm = compressionAlgorithm {
            dict[S.compressionAlgorithm] = compressionAlgorithm.rawValue
        }
        if let clientCertificate = clientCertificate {
            dict[S.clientCertificate] = clientCertificate.pem
        }
        if let clientKey = clientKey {
            dict[S.clientKey] = clientKey.pem
        }
        if let tlsWrapData = tlsWrap?.serialized() {
            dict[S.tlsWrap] = tlsWrapData
        }
        if let tlsSecurityLevel = tlsSecurityLevel {
            dict[S.tlsSecurityLevel] = tlsSecurityLevel
        }
        if let keepAliveSeconds = keepAliveInterval {
            dict[S.keepAlive] = keepAliveSeconds
        }
        if let keepAliveTimeoutSeconds = keepAliveTimeout {
            dict[S.keepAliveTimeout] = keepAliveTimeoutSeconds
        }
        if let renegotiatesAfterSeconds = renegotiatesAfter {
            dict[S.renegotiatesAfter] = renegotiatesAfterSeconds
        }
        if let checksEKU = checksEKU {
            dict[S.checksEKU] = checksEKU
        }
        if let checksSANHost = checksSANHost {
            dict[S.checksSANHost] = checksSANHost
        }
        if let sanHost = sanHost {
            dict[S.sanHost] = sanHost
        }
        if let randomizeEndpoint = randomizeEndpoint {
            dict[S.randomizeEndpoint] = randomizeEndpoint
        }
        if let usesPIAPatches = usesPIAPatches {
            dict[S.usesPIAPatches] = usesPIAPatches
        }
        if let dnsServers = dnsServers {
            dict[S.dnsServers] = dnsServers
        }
        if let searchDomains = searchDomains {
            dict[S.searchDomains] = searchDomains
        }
        if let httpProxy = httpProxy {
            dict[S.httpProxy] = httpProxy.rawValue
        }
        if let httpsProxy = httpsProxy {
            dict[S.httpsProxy] = httpsProxy.rawValue
        }
        if let proxyAutoConfigurationURL = proxyAutoConfigurationURL {
            dict[S.proxyAutoConfigurationURL] = proxyAutoConfigurationURL.absoluteString
        }
        if let proxyBypassDomains = proxyBypassDomains {
            dict[S.proxyBypassDomains] = proxyBypassDomains
        }
        if let routingPolicies = routingPolicies {
            dict[S.routingPolicies] = routingPolicies.map { $0.rawValue }
        }
    }
    
    func print() {
        guard let endpointProtocols = endpointProtocols else {
            fatalError("No sessionConfiguration.endpointProtocols set")
        }
        log.info("\tProtocols: \(endpointProtocols)")
        log.info("\tCipher: \(fallbackCipher)")
        log.info("\tDigest: \(fallbackDigest)")
        log.info("\tCompression framing: \(fallbackCompressionFraming)")
        if let compressionAlgorithm = compressionAlgorithm, compressionAlgorithm != .disabled {
            log.info("\tCompression algorithm: \(compressionAlgorithm)")
        } else {
            log.info("\tCompression algorithm: disabled")
        }
        if let _ = clientCertificate {
            log.info("\tClient verification: enabled")
        } else {
            log.info("\tClient verification: disabled")
        }
        if let tlsWrap = tlsWrap {
            log.info("\tTLS wrapping: \(tlsWrap.strategy)")
        } else {
            log.info("\tTLS wrapping: disabled")
        }
        if let tlsSecurityLevel = tlsSecurityLevel {
            log.info("\tTLS security level: \(tlsSecurityLevel)")
        } else {
            log.info("\tTLS security level: default")
        }
        if let keepAliveSeconds = keepAliveInterval, keepAliveSeconds > 0 {
            log.info("\tKeep-alive interval: \(keepAliveSeconds) seconds")
        } else {
            log.info("\tKeep-alive interval: never")
        }
        if let keepAliveTimeoutSeconds = keepAliveTimeout, keepAliveTimeoutSeconds > 0 {
            log.info("\tKeep-alive timeout: \(keepAliveTimeoutSeconds) seconds")
        } else {
            log.info("\tKeep-alive timeout: never")
        }
        if let renegotiatesAfterSeconds = renegotiatesAfter, renegotiatesAfterSeconds > 0 {
            log.info("\tRenegotiation: \(renegotiatesAfterSeconds) seconds")
        } else {
            log.info("\tRenegotiation: never")
        }
        if checksEKU ?? false {
            log.info("\tServer EKU verification: enabled")
        } else {
            log.info("\tServer EKU verification: disabled")
        }
        if checksSANHost ?? false {
            log.info("\tHost SAN verification: enabled (\(sanHost ?? "-"))")
        } else {
            log.info("\tHost SAN verification: disabled")
        }
        if randomizeEndpoint ?? false {
            log.info("\tRandomize endpoint: true")
        }
        if let routingPolicies = routingPolicies {
            log.info("\tGateway: \(routingPolicies.map { $0.rawValue })")
        } else {
            log.info("\tGateway: not configured")
        }
        if let dnsServers = dnsServers, !dnsServers.isEmpty {
            log.info("\tDNS: \(dnsServers.maskedDescription)")
        } else {
            log.info("\tDNS: not configured")
        }
        if let searchDomains = searchDomains, !searchDomains.isEmpty {
            log.info("\tSearch domains: \(searchDomains.maskedDescription)")
        }
        if let httpProxy = httpProxy {
            log.info("\tHTTP proxy: \(httpProxy.maskedDescription)")
        }
        if let httpsProxy = httpsProxy {
            log.info("\tHTTPS proxy: \(httpsProxy.maskedDescription)")
        }
        if let proxyAutoConfigurationURL = proxyAutoConfigurationURL {
            log.info("\tPAC: \(proxyAutoConfigurationURL)")
        }
        if let proxyBypassDomains = proxyBypassDomains {
            log.info("\tProxy bypass domains: \(proxyBypassDomains.maskedDescription)")
        }
    }
}
