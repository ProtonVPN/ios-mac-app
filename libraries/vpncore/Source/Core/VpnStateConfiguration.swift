//
//  VpnStateConfiguration.swift
//  Core
//
//  Created by Igor Kulman on 17.06.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension

public protocol VpnStateConfigurationFactory {
    func makeVpnStateConfiguration() -> VpnStateConfiguration
}

public struct VpnStateConfigurationInfo {
    public let state: VpnState
    public let hasConnected: Bool
    public let connection: ConnectionConfiguration?
}

public protocol VpnStateConfiguration {
    func determineActiveVpnProtocol(completion: @escaping ((VpnProtocol) -> Void))
    func determineActiveVpnState(vpnProtocol: VpnProtocol, completion: @escaping ((Result<(NEVPNManager, VpnState), Error>) -> Void))
    func determineNewState(vpnManager: NEVPNManager) -> VpnState
    func getInfo(completion: @escaping ((VpnStateConfigurationInfo) -> Void))
}

public class VpnStateConfigurationManager: VpnStateConfiguration {
    private let ikeProtocolFactory: VpnProtocolFactory
    private let openVpnProtocolFactory: VpnProtocolFactory
    private let wireguardProtocolFactory: VpnProtocolFactory
    private let propertiesManager: PropertiesManagerProtocol

    /// App group is used to read errors from OpenVPN in user defaults
    private let appGroup: String

    public init(ikeProtocolFactory: VpnProtocolFactory, openVpnProtocolFactory: VpnProtocolFactory, wireguardProtocolFactory: VpnProtocolFactory, propertiesManager: PropertiesManagerProtocol, appGroup: String) {
        self.ikeProtocolFactory = ikeProtocolFactory
        self.openVpnProtocolFactory = openVpnProtocolFactory
        self.wireguardProtocolFactory = wireguardProtocolFactory
        self.propertiesManager = propertiesManager
        self.appGroup = appGroup
    }

    public func determineNewState(vpnManager: NEVPNManager) -> VpnState {
        let status = vpnManager.connection.status
        let username = vpnManager.protocolConfiguration?.username ?? ""
        let serverAddress = vpnManager.protocolConfiguration?.serverAddress ?? ""

        switch status {
        case .invalid:
            return .invalid
        case .disconnected:
            if let error = lastError() {
                switch error {
                case ProtonVpnError.tlsServerVerification, ProtonVpnError.tlsInitialisation:
                    return .error(error)
                default: break
                }
            }
            return .disconnected
        case .connecting:
            return .connecting(ServerDescriptor(username: username, address: serverAddress))
        case .connected:
            return .connected(ServerDescriptor(username: username, address: serverAddress))
        case .reasserting:
            return .reasserting(ServerDescriptor(username: username, address: serverAddress))
        case .disconnecting:
            return .disconnecting(ServerDescriptor(username: username, address: serverAddress))
        }
    }

    public func determineActiveVpnProtocol(completion: @escaping ((VpnProtocol) -> Void)) {
        let dispatchGroup = DispatchGroup()

        var openVpnCurrentlyActive = false
        var wireGuardVpnCurrentlyActive = false

        dispatchGroup.enter()
        ikeProtocolFactory.vpnProviderManager(for: .status) { _, _ in
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        openVpnProtocolFactory.vpnProviderManager(for: .status) { [weak self] manager, error in
            guard let self = self, let manager = manager else {
                dispatchGroup.leave()
                return
            }

            let state = self.determineNewState(vpnManager: manager)
            if state.stableConnection || state.volatileConnection { // state is connected or in some kind of transition state
                openVpnCurrentlyActive = true
            }

            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        wireguardProtocolFactory.vpnProviderManager(for: .status) { [weak self] manager, error in
            guard let self = self, let manager = manager else {
                dispatchGroup.leave()
                return
            }

            let state = self.determineNewState(vpnManager: manager)
            if state.stableConnection || state.volatileConnection { // state is connected or in some kind of transition state
                wireGuardVpnCurrentlyActive = true
            }

            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            // OpenVPN takes precedence but if neither are active, then it should remain unchanged
            if openVpnCurrentlyActive {
                completion(.openVpn(.undefined))
            } else if wireGuardVpnCurrentlyActive {
                completion(.wireGuard)
            } else {
                completion(.ike)
            }
        }
    }

    public func determineActiveVpnState(vpnProtocol: VpnProtocol, completion: @escaping ((Result<(NEVPNManager, VpnState), Error>) -> Void)) {
        let activeFactory: VpnProtocolFactory
        switch vpnProtocol {
        case .ike:
            activeFactory = ikeProtocolFactory
        case .openVpn:
            activeFactory = openVpnProtocolFactory
        case .wireGuard:
            activeFactory = wireguardProtocolFactory
        }

        activeFactory.vpnProviderManager(for: .status) { [weak self] vpnManager, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let self = self, let vpnManager = vpnManager else {
                return
            }

            let newState = self.determineNewState(vpnManager: vpnManager)
            completion(.success((vpnManager, newState)))
        }
    }

    public func getInfo(completion: @escaping ((VpnStateConfigurationInfo) -> Void)) {
        determineActiveVpnProtocol { [weak self] vpnProtocol in
            guard let self = self else {
                return
            }

            let connection: ConnectionConfiguration?
            switch vpnProtocol {
            case .ike:
                connection = self.propertiesManager.lastIkeConnection
            case .openVpn:
                connection = self.propertiesManager.lastOpenVpnConnection
            case .wireGuard:
                connection = self.propertiesManager.lastWireguardConnection
            }

            self.determineActiveVpnState(vpnProtocol: vpnProtocol) { result in
                switch result {
                case let .failure(error):
                    completion(VpnStateConfigurationInfo(state: VpnState.error(error), hasConnected: self.propertiesManager.hasConnected, connection: connection))
                case let .success((_, state)):
                    completion(VpnStateConfigurationInfo(state: state, hasConnected: self.propertiesManager.hasConnected, connection: connection))
                }
            }
        }
    }

    private func lastError() -> Error? {
        let defaults = UserDefaults(suiteName: appGroup)
        let errorKey = "TunnelKitLastError"
        guard let lastError = defaults?.object(forKey: errorKey) else {
            return nil
        }
        if let error = lastError as? String {
            switch error {
            case "tlsServerVerification": return ProtonVpnError.tlsServerVerification
            case "tlsInitialization": return ProtonVpnError.tlsInitialisation
            default: break
            }
        }
        if let errorString = lastError as? String {
            return NSError(code: 0, localizedDescription: errorString)
        }
        return nil
    }
}
