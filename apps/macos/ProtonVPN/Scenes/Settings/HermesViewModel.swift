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
    public typealias Factory = CoreAlertServiceFactory &
        NetShieldPropertyProviderFactory &
        VpnStateConfigurationFactory &
        VpnGatewayFactory

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
    private let vpnStateConfiguration: any VpnStateConfiguration
    private let vpnGateway: any VpnGatewayProtocol
    private var netShieldPropertyProvider: any NetShieldPropertyProvider

    private let initialState: State

    private var isNetShieldEnabled: Bool {
        netShieldPropertyProvider.netShieldType != .off
    }

    private var windowListeningCancellable: AnyCancellable?

    init(factory: Factory) {
        @Dependency(\.hermesClient) var hermesClient
        let hermesIsEnabled = hermesClient.isEnabled()
        let resolvers = hermesClient.activeHermesResolvers()
        self._isEnabled = hermesIsEnabled
        self._activeHermesResolvers = hermesClient.activeHermesResolvers()
        self.alertService = factory.makeCoreAlertService()
        self.netShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
        self.vpnStateConfiguration = factory.makeVpnStateConfiguration()
        self.vpnGateway = factory.makeVpnGateway()
        self.initialState = .init(enabled: hermesIsEnabled.wrappedValue, resolvers: resolvers.wrappedValue)
        self.listenWindowEvents()
    }

    private func listenWindowEvents() {
        windowListeningCancellable = NotificationCenter.default
            .publisher(for: NSWindow.willCloseNotification)
            .compactMap { ($0.object as? HermesWindow) }
            .sink { [weak self] _ in
                self?.hermesWindowDidClose()
            }
    }

    func hermesWindowDidClose() {
        guard State(enabled: isEnabled, resolvers: activeHermesResolvers) != initialState else { return }
        vpnStateConfiguration.getInfo { [weak self] info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .immediate:
                break
            case .withConnectionUpdate, .withReconnect:
                self?.showAlert(.reconnectNecessary) {
                    self?.userConfirmsReconnection()
                }
            }
        }
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
        netShieldPropertyProvider.netShieldType = .off
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

    func moveResolvers(from source: IndexSet, to destination: Int) {
        hermesClient.reorderResolvers(source, destination)
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
