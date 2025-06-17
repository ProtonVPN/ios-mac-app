//
//  Created on 07/06/2024.
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

#if targetEnvironment(simulator)
    import Foundation

    import class NetworkExtension.NEOnDemandRule
    import class NetworkExtension.NETunnelProviderManager
    import class NetworkExtension.NETunnelProviderProtocol

    import IssueReporting

    final class MockTunnelProviderManager: TunnelProviderManager {
        var loadFromPreferencesBlock: (() -> Void)?
        var saveToPreferencesBlock: (() -> Void)?
        var localizedDescription: String?

        var state: MockProviderState

        /// According to NetworkExtension docs, manager must be loaded at least once before it can be saved
        enum MockProviderState {
            case requiresLoad
            case requiresSave
            case ready
        }

        init(
            session: VPNSession,
            vpnProtocolConfiguration: NETunnelProviderProtocol? = nil,
            onDemandRules: [NEOnDemandRule]? = nil,
            isOnDemandEnabled: Bool,
            isEnabled: Bool,
            state: MockProviderState = .ready
        ) {
            self.session = session
            self.vpnProtocolConfiguration = vpnProtocolConfiguration
            self.onDemandRules = onDemandRules
            self.isOnDemandEnabled = isOnDemandEnabled
            self.isEnabled = isEnabled
            self.state = state
        }

        func loadFromPreferences() async throws {
            state = .ready
            loadFromPreferencesBlock?()
        }

        func saveToPreferences() async throws {
            switch state {
            case .requiresSave:
                break

            case .requiresLoad:
                reportIssue("Manager requires load before it can be saved")

            case .ready:
                reportIssue("Redundant save")
            }

            state = .requiresLoad
            saveToPreferencesBlock?()
        }

        func removeFromPreferences() async throws {}

        var session: VPNSession

        var vpnProtocolConfiguration: NETunnelProviderProtocol? {
            didSet {
                onModification()
            }
        }

        var onDemandRules: [NEOnDemandRule]? {
            didSet {
                onModification()
            }
        }

        var isOnDemandEnabled: Bool {
            didSet {
                onModification()
            }
        }

        var isEnabled: Bool {
            didSet {
                onModification()
            }
        }

        private func onModification() {
            state = .requiresSave
        }
    }
#endif
