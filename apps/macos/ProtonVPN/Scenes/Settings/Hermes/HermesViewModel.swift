//
//  Created on 11/04/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
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

import AppKit
import Combine
import Observation

import CommonNetworking
import Domain
import Hermes
import LegacyCommon
import VPNAppCore

import Dependencies
import Sharing

final class HermesViewModel {
    public typealias Factory = CoreAlertServiceFactory & VpnGatewayFactory

    enum LocationValidation {
        case empty
        case duplicate
        case invalid
        case unexpectedError
        case valid
    }

    enum Error: Swift.Error {
        case upsellError
    }

    private struct State: Equatable {
        let enabled: Bool
        let resolvers: [HermesResolver]
    }

    @SharedReader var activeHermesResolvers: [HermesResolver]

    @SharedReader var isEnabled: Bool

    @Dependency(\.hermesClient) private var hermesClient
    @Dependency(\.sessionService) private var sessionService: SessionService
    @Dependency(\.linkOpener) private var linkOpener

    private let alertService: any CoreAlertService
    @Dependency(\.vpnStateConfiguration) private var vpnStateConfiguration
    private let vpnGateway: any VpnGatewayProtocol
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider

    private var initialState: State

    private var isNetShieldEnabled: Bool {
        netShieldPropertyProvider.getNetShieldType() != .off
    }

    init(factory: Factory) {
        @Dependency(\.hermesClient) var hermesClient
        let hermesIsEnabled = hermesClient.isEnabled()
        let resolvers = hermesClient.activeHermesResolvers()
        _isEnabled = hermesIsEnabled
        _activeHermesResolvers = hermesClient.activeHermesResolvers()
        self.alertService = factory.makeCoreAlertService()
        self.vpnGateway = factory.makeVpnGateway()
        self.initialState = .init(enabled: hermesIsEnabled.wrappedValue, resolvers: resolvers.wrappedValue)
    }

    func hermesWindowWillClose(completion: (() -> Void)? = nil) {
        let newState = State(enabled: isEnabled, resolvers: activeHermesResolvers)
        guard newState != initialState else {
            completion?()
            return
        }
        vpnStateConfiguration.getInfo { [weak self] info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .immediate:
                completion?()
            case .withConnectionUpdate, .withReconnect:
                self?.showAlert(.reconnectNecessary) {
                    self?.userConfirmsReconnection()
                    completion?()
                }
            }
        }
        initialState = newState
    }

    func setIsEnabled(_ newValue: Bool) {
        if isNetShieldEnabled, newValue {
            showAlert(.enableHermes) { [weak self] in
                self?.userEnablingHermesConfirmation()
            }
        } else {
            hermesClient.setIsEnabled(newValue)
        }
    }

    func userEnablingHermesConfirmation() {
        netShieldPropertyProvider.setNetShieldType(.off)
        hermesClient.setIsEnabled(true)
    }

    func userConfirmsReconnection() {
        vpnGateway.retryConnection()
    }

    func validate(location: String) -> LocationValidation {
        guard !location.isEmpty else { return .empty }
        if activeHermesResolvers.contains(where: { $0.location == location }) {
            return .duplicate
        }
        return hermesClient.validateHermesLocation(location) ? .valid : .invalid
    }

    func addResolver(with location: String) -> Bool {
        guard case .valid = validate(location: location) else {
            return false
        }
        do {
            let hermesResolver = try HermesResolver(ipAddress: location)
            return hermesClient.addHermesResolver(hermesResolver)
        } catch {
            return false
        }
    }

    func removeResolver(_ resolver: HermesResolver) -> Bool {
        if let index = activeHermesResolvers.firstIndex(of: resolver) {
            return hermesClient.removeHermesResolver(index)
        }
        return false
    }

    func applyDiff(_ difference: CollectionDifference<HermesResolver>) {
        hermesClient.applyDiff(difference)
    }

    func showAlert(
        _ type: HermesNotificationType,
        actionHandler: @escaping HermesAlertActionHandler,
        cancelHandler: HermesAlertActionHandler? = nil
    ) {
        alertService.push(alert: type.systemAlert(actionHandler, cancelHandler: cancelHandler))
    }

    func upsellButtonTapped() {
        alertService.push(alert: HermesUpsellAlert())
    }
}
