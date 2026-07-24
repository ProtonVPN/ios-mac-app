//
//  Created on 17/06/2026.
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

import Domain
import Ergonomics
import Foundation
import IPCDefinitions
import IPCErgonomics
import Network

// Marshaling between the live tunnel-data C payloads (LocalAgentIPC) and their Swift domain types.

/// Versions of the different RawChannel structs. Bump when changing formats to avoid ABI mismatch issues.
public enum IPCTunnelDataVersion {
    public static let connectionData: UInt16 = 1
    public static let stats: UInt16 = 1
    public static let connectionStats: UInt16 = 1
    public static let error: UInt16 = 1
    public static let agentFeatures: UInt16 = 1
}

public extension IPCConnectionTransport {
    init(_ transport: WireGuardTransport) {
        switch transport {
        case .udp: self = .wireGuardUdp
        case .tcp: self = .wireGuardTcp
        case .tls: self = .wireGuardTls
        }
    }

    /// The Swift transport, or `nil` if one hasn't yet been written.
    var wireGuardTransport: WireGuardTransport? {
        switch self {
        case .wireGuardUdp: .udp
        case .wireGuardTcp: .tcp
        case .wireGuardTls: .tls
        case .unset: nil
        @unknown default: nil
        }
    }
}

public extension IPCConnectionDataPayload {
    /// Peer ID uses Base64 URL encoding, we pack it here and add some length checks for encoding safety.
    var peerID: String {
        get {
            let bytes = withUnsafeBytes(of: peer_id) { Data($0) }
            guard bytes.contains(where: { $0 != 0 }) else { return "" }
            return bytes.base64URLEncodedString
        }
        set {
            withUnsafeMutableBytes(of: &peer_id) { raw in
                guard !newValue.isEmpty else {
                    for index in raw.indices {
                        raw[index] = 0 // Clear out the peer on state transitions if not connected
                    }
                    return
                }

                guard let bytes = Data(base64URLEncoded: newValue) else {
                    assertionFailure("peerID is not valid base64url, peer not published: \(newValue)")
                    return
                }

                guard bytes.count == raw.count else {
                    assertionFailure("peerID decoded to \(bytes.count) bytes, expected \(raw.count), peer not published: \(newValue)")
                    return
                }
                bytes.withUnsafeBytes { raw.copyMemory(from: $0) }
            }
        }
    }

    /// The server's exit IPv4 address, if any. Otherwise returns an empty string.
    var serverExitV4: String {
        get { withUnsafeBytes(of: server_exit_v4) { IPAddressPacking.string($0) ?? "" } }
        set { withUnsafeMutableBytes(of: &server_exit_v4) { IPAddressPacking.write(IPv4Address(newValue), into: $0) } }
    }

    /// The server's exit IPv6 address, if any. Otherwise returns an empty string.
    var serverExitV6: String {
        get { withUnsafeBytes(of: server_exit_v6) { IPAddressPacking.string($0) ?? "" } }
        set { withUnsafeMutableBytes(of: &server_exit_v6) { IPAddressPacking.write(IPv6Address(newValue), into: $0) } }
    }

    var userISP: String {
        get { withUnsafeBytes(of: user_isp) { IPCFixedString.read($0) } }
        set { withUnsafeMutableBytes(of: &user_isp) { IPCFixedString.write(newValue, into: $0) } }
    }

    /// The user's observed IP, packed by address family.
    var userIP: String {
        get {
            withUnsafeBytes(of: user_ipv4) { v4 in
                withUnsafeBytes(of: user_ipv6) { v6 in
                    IPAddressPacking.string(v4) ?? IPAddressPacking.string(v6) ?? ""
                }
            }
        }
        set {
            // At the moment this is either a v4 or a v6, so store whichever one returns a value and zero-out the other.
            withUnsafeMutableBytes(of: &user_ipv4) { IPAddressPacking.write(IPv4Address(newValue), into: $0) }
            withUnsafeMutableBytes(of: &user_ipv6) { IPAddressPacking.write(IPv6Address(newValue), into: $0) }
        }
    }

    /// Checks if the peer has a non-zero byte, in which case it's been written to.
    var hasPeer: Bool {
        withUnsafeBytes(of: peer_id) { raw in raw.contains { $0 != 0 } }
    }

    init(_ state: ExtensionState, id: UUID?) {
        self.init() // zeroes every field, so the cases below only set what applies
        version = IPCTunnelDataVersion.connectionData
        self.connectionState = state.connectionState
        self.requestId = id

        switch state {
        case let .disconnected(reason):
            self.reason = reason.rawValue
        case let .connecting(peerID, waitReason):
            self.reason = waitReason.rawValue
            if let peerID { self.peerID = peerID }
        case let .connectingToLocalAgent(peerID, waitReason, jail):
            self.reason = waitReason.rawValue
            context = jail.rawValue
            if let peerID { self.peerID = peerID }
        case let .connected(peer):
            self.reason = IPCConnectionTransport(peer.transport).rawValue
            self.peerID = peer.peerID
            self.port = peer.port
            self.serverExitV4 = peer.serverExitV4 ?? ""
            self.serverExitV6 = peer.serverExitV6 ?? ""
            self.userISP = peer.userISP ?? ""
            self.userIP = peer.userIP ?? ""
        }
    }

    /// The basic connection state, stored in the lower nibble of the `state` byte.
    var connectionState: IPCConnectionState {
        get { IPCConnectionState(rawValue: Int8(state & 0x0F)) ?? .disconnected }
        set { state = (state & 0xF0) | (UInt8(truncatingIfNeeded: newValue.rawValue) & 0x0F) }
    }

    /// Field accessor for the upper nibble of the `state` byte.
    ///
    /// If connected, contains the transport type.
    /// Otherwise, contains the reason why the tunnel is in that state, if any has been set.
    var reason: Int8 {
        get { Int8((state >> 4) & 0x0F) }
        set { state = (state & 0x0F) | ((UInt8(truncatingIfNeeded: newValue) & 0x0F) << 4) }
    }

    /// The connection state that gets reported to the main application.
    var extensionState: ExtensionState {
        ExtensionState(self)
    }

    var requestId: UUID? {
        get {
            guard withUnsafeBytes(of: config_id, { $0.contains(where: { $0 != 0 }) }) else { return nil }
            return UUID(uuid: config_id)
        }
        set {
            config_id = newValue?.uuid ?? zero(value: uuid_t.self)
        }
    }

    /// Unpacks the peer information from the binary format.
    var currentPeer: CurrentPeer? {
        guard hasPeer, let transport = IPCConnectionTransport(rawValue: reason)?.wireGuardTransport else {
            return nil
        }

        return CurrentPeer(
            peerID: peerID,
            transport: transport,
            port: port,
            serverExitV4: serverExitV4.isEmpty ? nil : serverExitV4,
            serverExitV6: serverExitV6.isEmpty ? nil : serverExitV6,
            userISP: userISP.isEmpty ? nil : userISP,
            userIP: userIP.isEmpty ? nil : userIP
        )
    }
}

public extension IPCStatsPayload {
    init(_ stats: LocalAgent.Stats) {
        self.init()
        version = IPCTunnelDataVersion.stats
        bytes_received = stats.bytesReceived ?? 0
        bytes_sent = stats.bytesSent ?? 0
        malicious_blocked = stats.maliciousBlocked ?? 0
        ads_blocked = stats.adsBlocked ?? 0
        trackers_blocked = stats.trackersBlocked ?? 0
        adult_content_blocked = stats.adultContentBlocked ?? 0
        data_saved = stats.dataSaved ?? 0
    }

    var localAgentStats: LocalAgent.Stats? {
        guard version != 0 else { return nil }
        return .init(
            bytesReceived: bytes_received,
            bytesSent: bytes_sent,
            maliciousBlocked: malicious_blocked,
            adsBlocked: ads_blocked,
            trackersBlocked: trackers_blocked,
            adultContentBlocked: adult_content_blocked,
            dataSaved: data_saved
        )
    }
}

public extension IPCConnectionStatsPayload {
    init(_ stats: LocalAgent.ConnectionStats) {
        self.init()
        version = IPCTunnelDataVersion.connectionStats
        timestamp_ms = stats.timestampMs
        received_bytes = stats.receivedBytes
        sent_bytes = stats.sentBytes
        time_since_last_handshake = stats.timeSinceLastHandshake
        estimated_loss = Double(stats.estimatedLoss)
        estimated_rtt = stats.estimatedRoundTripTime
    }

    /// The per-handshake metrics, or `nil` until the extension has published them (a zeroed region has `version == 0`).
    var localAgentConnectionStats: LocalAgent.ConnectionStats? {
        guard version != 0 else { return nil }
        return .init(
            timestampMs: timestamp_ms,
            receivedBytes: received_bytes,
            sentBytes: sent_bytes,
            timeSinceLastHandshake: time_since_last_handshake,
            estimatedLoss: Float(estimated_loss),
            estimatedRoundTripTime: estimated_rtt
        )
    }
}

// Marshalling helpers for error types
public extension IPCErrorPayload {
    var errorDomain: String {
        get { withUnsafeBytes(of: domain) { IPCFixedString.read($0) } }
        set { withUnsafeMutableBytes(of: &domain) { IPCFixedString.write(newValue, into: $0) } }
    }

    /// Checks the first character of the error domain to see if the payload has been written to.
    var hasError: Bool {
        domain.0 != 0
    }

    /// Encodes any error as a `(domain, code)` pair. Also works for ``ProtonVPNError``.
    init(_ error: any Error, requestId: UUID?) {
        self.init()
        version = IPCTunnelDataVersion.error

        let nsError = error as NSError
        self.errorDomain = nsError.domain.isEmpty ? "UnexpectedExtensionErrorDomain" : nsError.domain
        self.code = UInt32(truncatingIfNeeded: nsError.code)
        self.config_id = requestId?.uuid ?? zero(value: uuid_t.self)
    }

    var extensionError: ExtensionError? {
        guard hasError else { return nil }
        let requestId = withUnsafeBytes(of: config_id) { $0.contains { $0 != 0 } } ? UUID(uuid: config_id) : nil
        return ExtensionError(domain: errorDomain, code: code, requestId: requestId)
    }
}

public extension IPCAgentFeaturesPayload {
    init(_ features: AgentTunnelFeatures) {
        self.init()
        version = IPCTunnelDataVersion.agentFeatures
        netshield_level = UInt8(truncatingIfNeeded: features.netshield.rawValue)
        vpn_accelerator = features.vpnAccelerator ? 1 : 0
        moderate_nat = features.natType == .moderateNAT ? 1 : 0
        port_forwarding = (features.portForwarding ?? false) ? 1 : 0
    }

    /// The server-applied features, or `nil` if nothing has been written yet.
    var agentFeatures: AgentTunnelFeatures? {
        guard version != 0 else { return nil }
        return AgentTunnelFeatures(
            netshield: NetShieldType(rawValue: Int(netshield_level)) ?? .off,
            vpnAccelerator: vpn_accelerator != 0,
            natType: moderate_nat != 0 ? .moderateNAT : .strictNAT,
            portForwarding: port_forwarding != 0
        )
    }
}

/// Proton server/logical ids are base64url (RFC 4648 `-`/`_` instead of `+`/`/`) and unlike RFC 4648 retain the
/// `=` padding. Fix this optimistically with a simple find-replace, keeping the padding the encoder emits.
private extension Data {
    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    init?(base64URLEncoded string: String) {
        var standard = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = standard.count % 4
        if remainder > 0 { standard += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: standard)
    }
}
