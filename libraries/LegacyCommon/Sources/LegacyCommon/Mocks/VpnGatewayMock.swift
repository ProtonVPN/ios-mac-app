//
//  VpnGatewayMock.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

#if DEBUG
    import Foundation

    import Domain
    import VPNAppCore
    import VPNShared

    public class VpnGatewayMock: VpnGatewayProtocol {
        enum VpnGatewayMockError: Error {
            case missingUserTier
        }

        public static var connectionChanged: Notification.Name = .init("")
        public static var activeServerTypeChanged: Notification.Name = .init("")
        public static var needsReconnectNotification: Notification.Name = .init("")

        public init(userTier: Int? = nil) {
            self.connection = .disconnected
            self.activeServerType = .unspecified
            self._userTier = userTier
        }

        public init(propertiesManager: PropertiesManagerProtocol, activeServerType: ServerType, connection: ConnectionStatus) {
            self.connection = connection
            self.activeServerType = activeServerType

            propertiesManager.secureCoreToggle = activeServerType == .secureCore
        }

        public var connection: ConnectionStatus {
            didSet {
                AppEvent.connectionStateChanged.post(connection)
            }
        }

        public var activeIp: String?
        public var activeServer: ServerModel?
        public var lastConnectionRequest: ConnectionRequest?
        public var activeServerType: ServerType

        public var _userTier: Int?

        public func userTier() throws -> Int {
            guard let _userTier else { throw VpnGatewayMockError.missingUserTier }
            return _userTier
        }

        public func changeActiveServerType(_ serverType: ServerType) {
            activeServerType = serverType
        }

        public func autoConnect() {}

        public func quickConnect(trigger _: UserInitiatedVPNChange.VPNTrigger) {}

        public func quickConnectConnectionRequest(trigger: UserInitiatedVPNChange.VPNTrigger) -> ConnectionRequest {
            ConnectionRequest(serverType: .standard, connectionType: .fastest, connectionProtocol: .smartProtocol, netShieldType: .off, natType: .default, safeMode: true, profileId: nil, profileName: nil, trigger: trigger)
        }

        public func connectTo(serverGroup _: ServerGroupInfo.Kind, ofType _: ServerType, trigger _: UserInitiatedVPNChange.VPNTrigger) {}

        public func connectTo(server _: ServerModel) {}

        public func connectTo(profile _: Profile) {}

        public func retryConnection() {}

        public func connect(with _: ConnectionRequest?) {}

        public func connectTo(country _: String, city _: String) {}

        public func stopConnecting(userInitiated _: Bool) {
            connection = .disconnected
        }

        public func disconnect() {
            connection = .disconnected
        }

        public func disconnect(completion: @escaping () -> Void) {
            connection = .disconnected
            completion()
        }

        public func reconnect(with _: NetShieldType) {}

        public func reconnect(with _: NATType) {}

        public func reconnect(with _: ConnectionProtocol) {}

        public func postConnectionInformation() {}
    }
#endif
