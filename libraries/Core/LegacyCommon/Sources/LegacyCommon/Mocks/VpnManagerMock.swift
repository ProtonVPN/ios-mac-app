//
//  VpnManagerMock.swift
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
    import VPNShared

    import NetShield

    public class VpnManagerMock: VpnManagerProtocol {
        public var netShieldStats: NetShieldModel = .zero(enabled: false)

        private let serverDescriptor = ServerDescriptor(username: "", address: "")
        private var onDemand: Bool = false

        public var stateChanged: (() -> Void)?
        public var state: VpnState = .invalid {
            didSet {
                stateChanged?()

                if state == .disconnected {
                    disconnectCompletion?()
                    disconnectCompletion = nil
                }
            }
        }

        private var disconnectCompletion: (() -> Void)? = nil

        public var currentVpnProtocol: VpnProtocol? = .ike

        public init() {}

        public func isOnDemandEnabled(handler: (Bool) -> Void) {
            handler(onDemand)
        }

        public func setOnDemand(_ enabled: Bool) {
            onDemand = enabled
        }

        public func disconnectAnyExistingConnectionAndPrepareToConnect(
            with config: VpnManagerConfiguration,
            completion: @escaping () -> Void
        ) {
            didDisconnectAndPrepareToConnect?(config)
            completion()
        }

        public func disconnect(completion completion: @escaping () -> Void) {
            disconnectCompletion = completion
        }

        public func connectedDate(completion _: @escaping (Date?) -> Void) {}
        public func connectedDate() async -> Date? { nil }

        public func refreshState() {}

        public func appBackgroundStateDidChange(isBackground _: Bool) {}

        public func removeConfigurations(completionHandler: ((Error?) -> Void)? = nil) {
            completionHandler?(removeConfigurationError)
        }

        public var removeConfigurationError: Error?

        public func logsContent(for _: VpnProtocol, completion: @escaping (String?) -> Void) {
            completion(nil)
        }

        public func logFile(for _: VpnProtocol) -> URL? {
            nil
        }

        public func refreshManagers() {}
        public func whenReady(queue _: DispatchQueue, completion _: @escaping () -> Void) {}
        public var prepareManagersTask: Task<Void, Never>?

        public func set(vpnAccelerator _: Bool) {}

        public func set(netShieldType _: NetShieldType) {}

        public func set(natType _: NATType) {}

        public func set(safeMode _: Bool) {}

        public func set(portForwarding _: Bool) {}

        public private(set) var isLocalAgentConnected: Bool?
        public var localAgentStateChanged: ((Bool?) -> Void)?

        public func startNATPortMappingService() {}

        public func stopNATPortMappingService() {}

        public var didDisconnectAndPrepareToConnect: ((VpnManagerConfiguration) -> Void)?
    }
#endif
