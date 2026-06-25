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
import Foundation
import IPCErgonomics
import LocalAgentIPC

// Marshaling between the live tunnel-data C payloads (LocalAgentIPC) and their Swift domain types.

/// Versions of the different RawChannel structs. Bump when changing formats to avoid ABI mismatch issues.
public enum IPCTunnelDataVersion {
    public static let connectionData: Int32 = 1
    public static let stats: Int32 = 1
    public static let connectionStats: Int32 = 1
    public static let error: Int32 = 1
    public static let agentFeatures: Int32 = 1
}

public extension IPCConnectionWireGuardTransport {
    init(_ transport: WireGuardTransport) {
        switch transport {
        case .udp: self = .udp
        case .tcp: self = .tcp
        case .tls: self = .tls
        }
    }

    /// The Swift transport, or `nil` if one hasn't yet been written.
    var wireGuardTransport: WireGuardTransport? {
        switch self {
        case .udp: .udp
        case .tcp: .tcp
        case .tls: .tls
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

    var serverExitV4: String {
        get { withUnsafeBytes(of: server_exit_ip) { IPCFixedString.read($0) } }
        set { withUnsafeMutableBytes(of: &server_exit_ip) { IPCFixedString.write(newValue, into: $0) } }
    }

    var userISP: String {
        get { withUnsafeBytes(of: user_isp) { IPCFixedString.read($0) } }
        set { withUnsafeMutableBytes(of: &user_isp) { IPCFixedString.write(newValue, into: $0) } }
    }

    var userIP: String {
        get { withUnsafeBytes(of: user_ip) { IPCFixedString.read($0) } }
        set { withUnsafeMutableBytes(of: &user_ip) { IPCFixedString.write(newValue, into: $0) } }
    }

    /// Checks if the peer has a non-zero byte, in which case it's been written to.
    var hasPeer: Bool {
        withUnsafeBytes(of: peer_id) { raw in raw.contains { $0 != 0 } }
    }

    init(_ peer: CurrentPeer) {
        self.init()
        version = IPCTunnelDataVersion.connectionData
        transport = IPCConnectionWireGuardTransport(peer.transport)
        self.peerID = peer.peerID
        self.serverExitV4 = peer.serverExitV4 ?? ""
        self.userISP = peer.userISP ?? ""
        self.userIP = peer.userIP ?? ""
    }

    /// The peer as a domain value, or `nil` if no peer has been published yet.
    var currentPeer: CurrentPeer? {
        guard hasPeer, let transport = transport.wireGuardTransport else { return nil }
        return CurrentPeer(
            peerID: peerID,
            transport: transport,
            serverExitV4: serverExitV4.isEmpty ? nil : serverExitV4,
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
    init(_ error: any Error) {
        self.init()
        version = IPCTunnelDataVersion.error

        let nsError = error as NSError
        self.errorDomain = nsError.domain.isEmpty ? "UnexpectedExtensionErrorDomain" : nsError.domain
        self.code = UInt32(truncatingIfNeeded: nsError.code)
    }

    var extensionError: ExtensionError? {
        guard hasError else { return nil }
        return ExtensionError(domain: errorDomain, code: code)
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
