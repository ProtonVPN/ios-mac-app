//
//  Created on 31/05/2024.
//
//  Copyright (c) 2024 Proton AG
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

import ConnectionShared
import CoreConnection
import Dependencies
import DependenciesMacros
import Domain
import Foundation
import Hermes
import Localization
import NetworkExtension
import Sharing
import Strings
import VPNCoreCommon
import VPNCoreTypes
import VPNShared

public struct ConnectionConfiguration {
    /// Needed to detect connections started from another user (see AppSessionManager.resolveActiveSession)
    public let username: String
    public let wireguardConfig: WireguardConfig
}

public extension ConnectionConfiguration {
    static let testValue = ConnectionConfiguration(username: "mock_username", wireguardConfig: .init())
}

@DependencyClient
public struct ConnectionConfigurationProvider {
    public internal(set) var configuration: @Sendable () -> ConnectionConfiguration = { .testValue }
}

extension ConnectionConfigurationProvider: TestDependencyKey {
    public static let testValue = ConnectionConfigurationProvider { .testValue }
}

extension ConnectionConfigurationProvider: DependencyKey {
    public static var liveValue: ConnectionConfigurationProvider {
        ConnectionConfigurationProvider {
            @Dependency(\.hermesClient) var hermesClient

            let wireguardConfig = WireguardConfig(dns: hermesClient.currentResolvers.map(\.location))
            return ConnectionConfiguration(username: "ProtonVPN", wireguardConfig: wireguardConfig)
        }
    }
}

public extension DependencyValues {
    var connectionConfiguration: ConnectionConfigurationProvider {
        get { self[ConnectionConfigurationProvider.self] }
        set { self[ConnectionConfigurationProvider.self] = newValue }
    }
}

extension ManagerConfigurator {
    private static func providerConfiguration(with connectionIntent: ServerConnectionIntent) async throws -> NETunnelProviderProtocol {
        @Dependency(\.bundleIDClient) var bundleIDClient
        let bundleID: String = bundleIDClient.bundleIdentifier(connectionIntent.tunnelProtocol)
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = bundleID

        let server = connectionIntent.server

        guard case .wireGuard = connectionIntent.protocolConfiguration else {
            throw WireguardConfiguratorError.incorrectProtocolConfiguration
        }

        // Required for old wireguard extension:
        protocolConfiguration.connectedLogicalId = server.logical.id
        protocolConfiguration.connectedServerIpId = server.endpoint.id

        protocolConfiguration.serverAddress = "" // entryIP. If nil, start fails. Empty string prevents config
        protocolConfiguration.username = nil // Only required for IKEv2.

        @Dependency(\.connectionConfiguration) var connectionConfigurationProvider

        #if !os(tvOS)
            protocolConfiguration.includeAllNetworks = connectionIntent.tunnelFeatures.killSwitch
            protocolConfiguration.excludeLocalNetworks = connectionIntent.tunnelFeatures.excludeLocalNetworks
            if connectionIntent.tunnelFeatures.killSwitchMode.isAdvanced {
                protocolConfiguration.applyAdvancedKillSwitchExclusions()
            }
        #endif

        try encodeProTUNConfiguration(connectionIntent: connectionIntent, on: protocolConfiguration)
        return protocolConfiguration
    }

    /// Builds a ProTUN provider configuration with **no peers** (and no server), used to enforce Advanced
    /// kill switch blocking from a disconnected state. `includeAllNetworks` routes all traffic into a tunnel
    /// that never establishes a peer connection, so everything is blocked until the config is replaced.
    #if !os(tvOS)
        private static func zeroPeerProviderConfiguration() throws -> NETunnelProviderProtocol {
            @Dependency(\.bundleIDClient) var bundleIDClient
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = bundleIDClient.bundleIdentifier(.wireGuard)
            protocolConfiguration.serverAddress = "" // If nil, start fails. Empty string is accepted.
            protocolConfiguration.username = nil
            protocolConfiguration.includeAllNetworks = true
            // The zero-peer tunnel only exists under Advanced kill switch, so the default
            // exclusions are cleared unconditionally. `excludeLocalNetworks` follows the user's
            // current preference rather than the platform default, which lets LAN traffic through
            // on iOS but not on macOS.
            protocolConfiguration.applyAdvancedKillSwitchExclusions()
            @Dependency(\.connectionFeatureProvider) var connectionFeatureProvider
            protocolConfiguration.excludeLocalNetworks = connectionFeatureProvider.requestedFeatures().excludeLocalNetworks

            @Dependency(\.connectionConfiguration) var connectionConfigurationProvider
            let wgConfig = connectionConfigurationProvider.configuration().wireguardConfig
            let config = ProTUNConfiguration(preferredTransport: .udp, peers: [], dnsServers: wgConfig.dnsServers ?? [])
            try ProTUNConfigurationCoder.encode(configuration: config, to: protocolConfiguration)

            try protocolConfiguration.setConnectionSpec(ConnectionSpec())
            // Required so `resolveProTUN` can quiesce (appliedRequestId == requestId) and report `.killSwitchActive`
            // once the extension settles into zero-peer mode; without it the app would stay `.connecting` forever.
            @Dependency(\.uuid) var uuid
            protocolConfiguration.requestId = uuid()

            @Dependency(\.authKeychain) var authKeychain
            guard let userID = authKeychain.userId else {
                throw ManagerConfigurationError.userIdMissing
            }
            protocolConfiguration.userID = userID
            return protocolConfiguration
        }
    #endif

    static func encodeProTUNConfiguration(connectionIntent: ServerConnectionIntent, on protocolConfiguration: NETunnelProviderProtocol) throws {
        @Dependency(\.connectionConfiguration) var connectionConfigurationProvider

        let wgConfig = connectionConfigurationProvider.configuration().wireguardConfig
        let features = appropriateFeatures

        // Encode every peer with the full set of transports/ports, so that we can reconfigure the connection with a
        // specific transport later without supplying a new set of peers.
        let peers = try connectionIntent.server.peerInfo(using: wgConfig)
        let preferredTransport = connectionIntent.preferredWireGuardTransport
        let config = ProTUNConfiguration(
            preferredTransport: preferredTransport,
            peers: peers,
            dnsServers: wgConfig.dnsServers ?? [],
            netShieldLevel: features?.netshield.rawValue,
            vpnAccelerator: features?.vpnAccelerator,
            portForwarding: features.flatMap(\.portForwarding),
            randomNat: features?.natType.flag
        )
        try ProTUNConfigurationCoder.encode(configuration: config, to: protocolConfiguration)
        try protocolConfiguration.setConnectionSpec(connectionIntent.spec)
        protocolConfiguration.requestId = UUID()

        // The userID is used by ProTUN to store credentials (certs, tokens) in a distinct bucket per user
        @Dependency(\.authKeychain) var authKeychain
        guard let userID = authKeychain.userId else {
            throw ManagerConfigurationError.userIdMissing
        }
        protocolConfiguration.userID = userID
    }

    private static var appropriateFeatures: AgentTunnelFeatures? {
        @Dependency(\.connectionFeatureProvider) var connectionFeatureProvider
        @Dependency(\.credentiallessHelper) var credentiallessHelper
        @SharedReader(.userTier) var userTier: VpnTier?

        let shouldReturnNil = userTier?.isFree == true || credentiallessHelper.isCredentialLess()

        return shouldReturnNil ? nil : connectionFeatureProvider.connectionFeatures()
    }

    static var wireGuardConfigurator: ManagerConfigurator {
        ManagerConfigurator(
            changes: { intent in
                @Dependency(\.connectionConfiguration) var configurationProvider
                let wireguardConfig = configurationProvider.configuration().wireguardConfig
                let peers = try intent.server.peerInfo(using: wireguardConfig)
                let connectionProtocol = intent.connectionProtocol
                if case .vpnProtocol(.ike) = connectionProtocol {
                    log.assertionFailure("Unexpected protocol passed to WireGuardConfigurator (IKE)")
                }
                return ConnectionUpdate(
                    location: .init(spec: intent.spec, peers: peers),
                    connectionProtocol: connectionProtocol
                )
            },
            configure: { manager, operation in
                manager.onDemandRules = [NEOnDemandRuleConnect()]

                switch operation {
                case let .connection(connectionIntent):
                    switch connectionIntent.protocolConfiguration {
                    case .ike:
                        manager.protocolConfiguration = try ikeConfiguration(with: connectionIntent)
                    case .wireGuard:
                        let protocolConfig = try await providerConfiguration(with: connectionIntent)
                        // Connecting builds a provider configuration from scratch, so carry over the capture the app
                        // declared beforehand. Otherwise the connection a capture is waiting for is the very thing that
                        // discards it.
                        protocolConfig.pcapCaptureFileURL = manager.vpnProtocolConfiguration?.pcapCaptureFileURL
                        manager.vpnProtocolConfiguration = protocolConfig
                    }
                    manager.localizedDescription = configurationTitle(for: connectionIntent)

                    manager.isOnDemandEnabled = true
                    manager.isEnabled = true

                case let .update(update):
                    guard let protocolConfig = manager.vpnProtocolConfiguration else {
                        throw WireguardConfiguratorError.incorrectProtocolConfiguration
                    }
                    #if !os(tvOS)
                        let wasBlocking = isZeroPeerBlocking(protocolConfig)
                    #endif
                    // The app applies the updated protocol configuration, but we still need to send the change request
                    // to ProTUN so it can confirm the change.
                    try protocolConfig.apply(update: update)
                    manager.vpnProtocolConfiguration = protocolConfig
                    #if !os(tvOS)
                        if isZeroPeerBlocking(protocolConfig) {
                            manager.localizedDescription = killSwitchConfigurationTitle
                        } else if wasBlocking {
                            manager.localizedDescription = defaultConfigurationTitle
                        }
                    #endif

                case let .packetCapture(fileURL):
                    // Only the capture declaration changes here. Leaving the tunnel's enabled and on-demand state alone
                    // keeps starting a capture from disturbing a connection, or making one.
                    if let protocolConfig = manager.vpnProtocolConfiguration {
                        protocolConfig.pcapCaptureFileURL = fileURL
                        manager.vpnProtocolConfiguration = protocolConfig
                    } else if let fileURL {
                        // A declaration can precede the first connection ever configured. A minimal configuration
                        // sets it up, to be amended by the first connection attempt.
                        @Dependency(\.bundleIDClient) var bundleIDClient
                        let protocolConfig = NETunnelProviderProtocol()
                        protocolConfig.providerBundleIdentifier = bundleIDClient.bundleIdentifier(.wireGuard)
                        protocolConfig.serverAddress = ""
                        protocolConfig.pcapCaptureFileURL = fileURL
                        manager.vpnProtocolConfiguration = protocolConfig
                    }

                case .disconnection:
                    #if !os(tvOS)
                        // Turn off Kill Switch as the user asks for it, rather than when the tunnel finishes going
                        // down. NetworkExtension keeps its drop-all rule in place for as long as the saved
                        // configuration asks for every network, and its teardown runs for seconds after the extension
                        // has already stopped, which reads as the connection being broken after the user disconnected.
                        // Standard blocks unexpected drops, and an unexpected drop never comes through here.
                        if let configuration = manager.protocolConfiguration {
                            configuration.includeAllNetworks = false
                            manager.protocolConfiguration = configuration
                        }
                    #endif
                    manager.isOnDemandEnabled = false
                    manager.isEnabled = true

                #if !os(tvOS)
                    case .zeroPeerColdStart:
                        let zeroPeerConfig = try zeroPeerProviderConfiguration()
                        // A zero-peer tunnel has nothing to capture, but the declaration still belongs to the app and
                        // has to survive for whichever real connection comes next.
                        zeroPeerConfig.pcapCaptureFileURL = manager.vpnProtocolConfiguration?.pcapCaptureFileURL
                        manager.vpnProtocolConfiguration = zeroPeerConfig
                        manager.localizedDescription = killSwitchConfigurationTitle
                        manager.isOnDemandEnabled = false
                        manager.isEnabled = true
                #endif
                }
            }
        )
    }

    /// The base manager name shown in the system's VPN settings.
    private static let defaultConfigurationTitle = "Proton VPN"

    /// The manager name shown in the system settings while the tunnel is the zero-peer blackhole.
    private static var killSwitchConfigurationTitle: String {
        "\(defaultConfigurationTitle) (\(Localizable.killSwitch))"
    }

    #if !os(tvOS)
        /// A configuration with the kill switch flag and no peers describes the zero-peer blackhole.
        private static func isZeroPeerBlocking(_ configuration: NETunnelProviderProtocol) -> Bool {
            configuration.includeAllNetworks && ((try? configuration.peerIDs) ?? []).isEmpty
        }
    #endif

    private static func configurationTitle(for intent: ServerConnectionIntent) -> String {
        #if DEBUG
            let serverName = intent.server.logical.name
            let connectionProtocol: String = switch intent.protocolConfiguration {
            case .ike:
                "IKEv2"
            case let .wireGuard(wgSettings):
                switch wgSettings.backend {
                case .go:
                    wgSettings.transport.map { VpnProtocol.wireGuard($0).localizedDescription } ?? "Smart"
                case .proTUN:
                    if let transport = wgSettings.transport {
                        "ProTUN (\(transport))"
                    } else {
                        "ProTUN"
                    }
                }
            }
            return "\(serverName) - \(connectionProtocol)"
        #else
            return defaultConfigurationTitle
        #endif
    }

    private static func ikeConfiguration(with intent: ServerConnectionIntent) throws -> NEVPNProtocolIKEv2 {
        let config = NEVPNProtocolIKEv2()

        @Dependency(\.vpnKeychain) var keychain
        let username: String
        let passwordReference: Data
        do {
            let credentials = try keychain.fetch()
            username = credentials.name
            passwordReference = try keychain.fetchOpenVpnPassword()
        } catch {
            throw IkeConfiguratorError.ikeCredentialsUnavailable(error)
        }

        config.username = ikeUsername(baseUsername: username, features: intent.features, endpointID: intent.server.endpoint.id)
        config.passwordReference = passwordReference

        config.localIdentifier = username // makes it easier to troubleshoot connection issues server-side
        config.remoteIdentifier = intent.server.logical.domain
        config.serverAddress = intent.server.endpoint.entryIp
        config.useExtendedAuthentication = true
        config.disconnectOnSleep = false
        config.enablePFS = false
        config.deadPeerDetectionRate = .high

        #if os(macOS)
            config.authenticationMethod = .certificate
            config.serverCertificateIssuerCommonName = "ProtonVPN Root CA"

            // Advanced kill switch needs ProTUN's zero-peer blocking and the settings UI prevents combining it with
            // IKEv2, so a protected mode here means Standard behavior, and Apple's default tunnel
            // exclusions stay in place.
            config.includeAllNetworks = intent.tunnelFeatures.killSwitch
            config.excludeLocalNetworks = intent.tunnelFeatures.excludeLocalNetworks
        #endif

        config.disableMOBIKE = false
        config.disableRedirect = false
        config.enableRevocationCheck = false
        config.useConfigurationAttributeInternalIPSubnet = false

        config.ikeSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
        config.ikeSecurityAssociationParameters.integrityAlgorithm = .SHA384
        config.ikeSecurityAssociationParameters.diffieHellmanGroup = .group20 // .group15
        config.ikeSecurityAssociationParameters.lifetimeMinutes = 480

        config.childSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256
        config.childSecurityAssociationParameters.integrityAlgorithm = .SHA256
        config.childSecurityAssociationParameters.diffieHellmanGroup = .group20
        config.childSecurityAssociationParameters.lifetimeMinutes = 60

        return config
    }

    private static func ikeUsername(baseUsername: String, features: AgentTunnelFeatures, endpointID: String) -> String {
        let components = ikeUsernameComponents(features: features, endpointID: endpointID)
        let suffix = components.reduce("") {
            $0 + "\(IkeUsernameComponent.concatChar)" + $1.usernameSuffix
        }
        return baseUsername + suffix
    }

    private static func ikeUsernameComponents(features: AgentTunnelFeatures, endpointID: String) -> [IkeUsernameComponent] {
        #if os(iOS)
            var components: [IkeUsernameComponent] = [.iosClient]
        #else
            var components: [IkeUsernameComponent] = [.macClient]
        #endif

        switch features.netshield {
        case .off:
            break
        case .level1:
            components += [.netShieldLevel1]
        case .level2:
            components += [.netShieldLevel2]
        case .level3:
            components += [.netShieldLevel3]
        }

        // Legacy encoding uses inverted logic for accelerator:
        // send `nst` when accelerator is disabled.
        if !features.vpnAccelerator {
            components += [.vpnAcceleratorDisabled]
        }

        if features.natType == .moderateNAT {
            components += [.moderateNAT]
        }

        if features.portForwarding == true {
            components += [.portForwardingEnabled]
        }

        // Endpoint token must be explicit to avoid collisions with feature flags.
        components += [.endpointID(endpointID)]
        return components
    }
}

enum WireguardConfiguratorError: Error {
    case incorrectProtocolConfiguration
    case configurationEncodingError(Error)
    case keychainImplementationError(TunnelKeychainImplementationError)
    case keychainError(Error)
}

extension WireguardConfiguratorError: ProtonVPNError {
    var charCode: FourCharCode {
        switch self {
        case .incorrectProtocolConfiguration:
            "WGPC"
        case .configurationEncodingError:
            "WGCE"
        case .keychainImplementationError:
            "WGKI"
        case .keychainError:
            "WGKC"
        }
    }

    var underlyingError: Error? {
        switch self {
        case let .configurationEncodingError(error), let .keychainError(error):
            error
        case let .keychainImplementationError(error):
            error
        case .incorrectProtocolConfiguration:
            nil
        }
    }

    var errorDescription: String? {
        includeCode(inside: Localizable.connectionErrorConfiguration)
    }
}

/// Errors raised while building an IKEv2 `NEVPNProtocolIKEv2` configuration. Kept separate
/// from `WireguardConfiguratorError` so callers can pattern-match on protocol-specific
/// failures without conflating the two transports.
enum IkeConfiguratorError: Error {
    /// VPN keychain credentials could not be read while preparing the IKE configuration.
    case ikeCredentialsUnavailable(Error)
}

extension IkeConfiguratorError: ProtonVPNError {
    var charCode: FourCharCode {
        switch self {
        case .ikeCredentialsUnavailable:
            "IKCU"
        }
    }

    var underlyingError: Error? {
        switch self {
        case let .ikeCredentialsUnavailable(error):
            error
        }
    }

    var errorDescription: String? {
        includeCode(inside: Localizable.connectionErrorConfiguration)
    }
}

enum IkeUsernameComponent {
    static let concatChar: Character = "+"
    /// Token that prefixes the `endpointID(...)` chunk inside the encoded IKE username.
    /// Defined once so the decode side (`TunnelManager.ikePeerID`) and the encode side
    /// (`usernameSuffix`) can't drift apart.
    static let endpointIDPrefix = "ep:"

    case iosClient
    case macClient
    case netShieldLevel1
    case netShieldLevel2
    case netShieldLevel3
    case vpnAcceleratorDisabled
    case label(String)
    case moderateNAT
    case portForwardingEnabled
    case endpointID(String)

    var usernameSuffix: String {
        switch self {
        case .iosClient:
            "pi"
        case .macClient:
            "pm"
        case .netShieldLevel1:
            "f1"
        case .netShieldLevel2:
            "f2"
        case .netShieldLevel3:
            "f3"
        case .vpnAcceleratorDisabled:
            "nst"
        case let .label(label):
            "b:\(Self.sanitized(label, context: "bouncing label"))"
        case .moderateNAT:
            "nr"
        case .portForwardingEnabled:
            "pmp"
        case let .endpointID(endpointID):
            "\(Self.endpointIDPrefix)\(Self.sanitized(endpointID, context: "endpoint ID"))"
        }
    }

    /// Strips IKE-username reserved characters (`+` and `:`) from arbitrary string payloads
    /// such as the bouncing label or endpoint ID. In DEBUG builds also fires an
    /// `assertionFailure` so the offending input is caught during development; in release we
    /// fall through with a sanitized value rather than producing a username that the server
    /// can't parse unambiguously.
    private static func sanitized(_ value: String, context: String) -> String {
        let reserved: Set<Character> = [concatChar, ":"]
        guard value.contains(where: { reserved.contains($0) }) else {
            return value
        }
        assertionFailure(
            "IKE username \(context) contains reserved character (`+` or `:`): '\(value)'. " +
                "Server-side parser would receive an ambiguous suffix."
        )
        return String(value.filter { !reserved.contains($0) })
    }
}

extension Server {
    /// Returns an array of peers with distinct serverIP values.
    ///
    /// Usually, this will contain just one peer with ports defined for each transport.
    /// But, if the IP address of the server has been overridden for any of the transports, the array will include an
    /// additional peer for each. If the IP is overridden for each transport, there will **not** be a fourth peer with
    /// the default IP.
    ///
    /// - Throws: `entryIpMissing` when the endpoint has no address for any transport.
    func peerInfo(using wgConfig: WireguardConfig) throws(ManagerConfigurationError) -> [ProTUNConfiguration.Peer] {
        let peers = try [peerWithDefaultIP(with: wgConfig)].compactMap { $0 }
            + peersWithOverriddenIPs(with: wgConfig)

        guard !peers.isEmpty else {
            throw .entryIpMissing
        }
        return peers
    }

    private func peerWithDefaultIP(
        with config: WireguardConfig
    ) throws(ManagerConfigurationError) -> ProTUNConfiguration.Peer? {
        // With no default address there is no default peer. Every transport this endpoint serves has an
        // address of its own, and `peersWithOverriddenIPs` builds a peer for each one.
        guard let entryIp = endpoint.entryIp else {
            return nil
        }
        let perTransportPortOverrides: [Domain.WireGuardTransport: [UInt16]] = Domain.WireGuardTransport.allCases
            .reduce(into: [:]) { overrides, transport in
                let usesDefaultIp = endpoint.entryIp(using: .wireGuard(transport)) == entryIp
                guard usesDefaultIp else {
                    // Skip this transport if it uses a custom IP, or has no address at all
                    return
                }
                overrides[transport] = ports(for: transport, with: config)
            }
        if perTransportPortOverrides.isEmpty {
            // No transports use the default IP, so we shouldn't return the default peer
            return nil
        }
        guard let serverPublicKey = endpoint.x25519PublicKey else {
            throw .emptyServerPublicKey
        }
        return ProTUNConfiguration.Peer(
            id: endpoint.id,
            serverIP: entryIp,
            serverPublicKey: serverPublicKey,
            udpPorts: perTransportPortOverrides[.udp] ?? [],
            tcpPorts: perTransportPortOverrides[.tcp] ?? [],
            tlsPorts: perTransportPortOverrides[.tls] ?? [],
            priority: 0,
            exitLabel: endpoint.label
        )
    }

    private func peersWithOverriddenIPs(
        with config: WireguardConfig
    ) throws(ManagerConfigurationError) -> [ProTUNConfiguration.Peer] {
        let overriddenTransports = Domain.WireGuardTransport.allCases
            .compactMap { transport -> (Domain.WireGuardTransport, String)? in
                guard let customIp = endpoint.entryIp(using: .wireGuard(transport)) else {
                    // Skip this transport if no custom IP is defined
                    return nil
                }
                if customIp == endpoint.entryIp {
                    // Sanity check
                    return nil
                }
                return (transport, customIp)
            }
        guard !overriddenTransports.isEmpty else {
            return []
        }
        guard let serverPublicKey = endpoint.x25519PublicKey else {
            throw .emptyServerPublicKey
        }
        return overriddenTransports.map { transport, customIp in
            ProTUNConfiguration.Peer(
                id: endpoint.id,
                serverIP: customIp,
                serverPublicKey: serverPublicKey,
                udpPorts: transport == .udp ? ports(for: .udp, with: config) : [],
                tcpPorts: transport == .tcp ? ports(for: .tcp, with: config) : [],
                tlsPorts: transport == .tls ? ports(for: .tls, with: config) : [],
                priority: 0,
                exitLabel: endpoint.label
            )
        }
    }

    private func ports(for transport: Domain.WireGuardTransport, with config: WireguardConfig) -> [UInt16] {
        let ports = endpoint.overridePorts(using: .wireGuard(transport)) ?? config.defaultPorts(for: transport)
        return ports.map { UInt16($0) }
    }
}

private extension ServerConnectionIntent {
    var preferredWireGuardTransport: VPNCoreTypes.WireGuardTransport? {
        switch protocolConfiguration {
        case .ike:
            nil
        case let .wireGuard(settings):
            settings.transport.map { VPNCoreTypes.WireGuardTransport.from($0) }
        }
    }

    var connectionProtocol: ConnectionProtocol {
        switch protocolConfiguration {
        case .ike:
            .vpnProtocol(.ike)
        case let .wireGuard(settings):
            settings.transport.map { .vpnProtocol(.wireGuard($0)) } ?? .smartProtocol
        }
    }
}

extension VPNCoreTypes.WireGuardTransport {
    static func from(_ transport: Domain.WireGuardTransport) -> VPNCoreTypes.WireGuardTransport {
        switch transport {
        case .udp:
            .udp
        case .tcp:
            .tcp
        case .tls:
            .tls
        }
    }
}

extension WireguardConfig {
    func defaultPorts(for transport: Domain.WireGuardTransport) -> [Int] {
        switch transport {
        case .udp:
            defaultUdpPorts
        case .tcp:
            defaultTcpPorts
        case .tls:
            defaultTlsPorts
        }
    }
}

enum ManagerConfigurationError: Error, Equatable {
    case entryIpMissing
    case emptyServerPublicKey
    case userIdMissing
}

extension ManagerConfigurationError: ProtonVPNError {
    var charCode: FourCharCode {
        switch self {
        case .entryIpMissing:
            "MCEI"
        case .emptyServerPublicKey:
            "MCPK"
        case .userIdMissing:
            "MCUI"
        }
    }

    var errorDescription: String? {
        includeCode(inside: Localizable.connectionErrorConfigurationInvalid)
    }
}
