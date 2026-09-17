//
//  Created on 21/08/2026.
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

#if os(macOS)
    import Dependencies
    import Foundation
    import Network
    import NetworkExtension
    import os

    /// Shares kill switch policy between the tunnel and packet filter providers in the same extension.
    final class PacketFilterCoordinator: Sendable {
        private struct State {
            var policy: PacketFilterPolicy = .failClosed
            /// The packet filtering policy in "packed" form, kept in this format for performance reasons.
            var lookup = PacketFilterPolicy.Lookup(.failClosed)
            var isFilterActive = false
            /// How many packets the filter dropped since the last report.
            var drops = DroppedPacketCounts()
        }

        private enum Constants {
            /// How many leading bytes of an unparseable packet the log shows.
            static let sampleLength = 64
        }

        private let state = OSAllocatedUnfairLock<State>(initialState: State())

        /// The tunnel provider checks this before it exits, since doing so would take the filter down with it.
        var isFilterActive: Bool {
            state.withLock { $0.isFilterActive }
        }

        var drops: DroppedPacketCounts {
            state.withLock { $0.drops }
        }

        func filterDidStart() {
            let policy = state.withLock {
                $0.isFilterActive = true
                return $0.policy
            }
            Logger.packetFilter.info(
                "Packet filter started, enforcing: \(String(describing: policy), privacy: .public)"
            )
        }

        func filterDidStop() {
            let drops = state.withLock { current in
                current.isFilterActive = false
                return current.drops.take()
            }
            Logger.packetFilter.info(
                "Packet filter stopped, dropped since the last report: \(drops.description, privacy: .public)"
            )
        }

        func update(policy: PacketFilterPolicy) {
            let dropsFromLastPolicy: DroppedPacketCounts? = state.withLock { current in
                guard current.policy != policy else { return nil }
                current.policy = policy
                current.lookup = PacketFilterPolicy.Lookup(policy)
                return current.drops.take()
            }

            guard let dropsFromLastPolicy else { return }
            Logger.packetFilter.info("Policy updated: \(String(describing: policy), privacy: .public)")
            Logger.packetFilter.info(
                "Dropped under the previous policy: \(dropsFromLastPolicy.description, privacy: .public)"
            )
        }

        /// Decides whether the current policy allows the packet through. Any traffic that is over the loopback
        /// interface (local-only) or the VPN gets automatically allowed. Other packets get inspected according to the
        /// packed firewall rule set before either getting allowed, or blocked and counted. Unparseable packets get
        /// counted separately, with the first unparseable packet of a session getting logged.
        func verdict(
            interfaceIndex: UInt32,
            interfaceType: nw_interface_type_t,
            direction: NETrafficDirection,
            packet: RawSpan
        ) -> NEFilterPacketProvider.Verdict {
            state.withLockUnchecked { current in
                if interfaceType == nw_interface_type_loopback || current.lookup.isTunnel(interfaceIndex) {
                    return .allow
                }
                guard let parsed = ParsedPacket(packet) else {
                    current.drops.unparseable += 1
                    if current.drops.unparseable == 1 {
                        Self.logUnparseable(packet, direction: direction)
                    }
                    return .drop
                }
                guard current.lookup.allows(parsed, direction: direction) else {
                    current.drops.blocked += 1
                    return .drop
                }
                return .allow
            }
        }

        /// Logs the packet's length, direction, and leading bytes.
        private static func logUnparseable(_ packet: RawSpan, direction: NETrafficDirection) {
            let hex = packet.withUnsafeBytes { bytes in
                bytes.prefix(Constants.sampleLength).map { String(format: "%02x", $0) }.joined()
            }
            let byteCount = packet.byteCount
            let direction = direction.rawValue
            Logger.packetFilter.info(
                "First unparseable packet, \(byteCount) bytes, direction \(direction): \(hex, privacy: .public)"
            )
        }
    }

    extension PacketFilterCoordinator: DependencyKey {
        static let liveValue = PacketFilterCoordinator()
        static var testValue: PacketFilterCoordinator {
            PacketFilterCoordinator()
        }
    }

    extension DependencyValues {
        var packetFilterCoordinator: PacketFilterCoordinator {
            get { self[PacketFilterCoordinator.self] }
            set { self[PacketFilterCoordinator.self] = newValue }
        }
    }
#endif
