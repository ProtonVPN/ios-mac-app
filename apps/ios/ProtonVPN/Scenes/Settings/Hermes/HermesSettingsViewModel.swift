//
//  Created on 26/05/2025 by adam.
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

import SwiftUI

import Dependencies
import Perception
import Sharing

import Domain
import Hermes
import LegacyCommon
import Strings

@Perceptible
final class HermesSettingsViewModel {
    public typealias Factory = CoreAlertServiceFactory &
        NetShieldPropertyProviderFactory &
        VpnGatewayFactory &
        VpnStateConfigurationFactory

    enum LocationValidation {
        case empty
        case duplicate
        case invalid
        case unexpectedError
        case valid
    }

    enum Alert {
        case hermesOnConflict
        case netShieldOnConflict
        case netShieldOnConflictAndShouldReconnect
        case confirmChanges
        case duplicate
        case invalid
        case unexpectedError
    }

    private struct State: Equatable {
        let enabled: Bool
        let resolvers: [HermesResolver]
    }

    @PerceptionIgnored
    @SharedReader var activeHermesResolvers: [HermesResolver]

    @PerceptionIgnored
    @SharedReader var isEnabled: Bool

    @PerceptionIgnored
    @Dependency(\.hermesClient) private var hermesClient

    var isNetShieldEnabled: Bool {
        netShieldPropertyProvider.netShieldType != .off
    }

    var alert: Alert?

    private let vpnGateway: any VpnGatewayProtocol
    private let vpnStateConfiguration: any VpnStateConfiguration
    private var netShieldPropertyProvider: any NetShieldPropertyProvider

    private var initialState: State

    init(factory: Factory) {
        @Dependency(\.hermesClient) var hermesClient
        let hermesIsEnabled = hermesClient.isEnabled()
        let resolvers = hermesClient.activeHermesResolvers()
        self._isEnabled = hermesIsEnabled
        self._activeHermesResolvers = hermesClient.activeHermesResolvers()
        self.vpnGateway = factory.makeVpnGateway()
        self.vpnStateConfiguration = factory.makeVpnStateConfiguration()
        self.netShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
        self.initialState = .init(enabled: hermesIsEnabled.wrappedValue, resolvers: resolvers.wrappedValue)
    }

    func onAppear() {
        initialState = State(enabled: isEnabled, resolvers: activeHermesResolvers)
    }

    func setIsEnabled(_ newValue: Bool, force: Bool = false) {
        guard !force else {
            hermesClient.setIsEnabled(newValue)
            return
        }
        if isNetShieldEnabled, newValue {
            alert = .hermesOnConflict
        } else {
            hermesClient.setIsEnabled(newValue)
        }
    }

    func isReconnectionNecessaryFromHermesChange(completionHandler: @escaping (_ reconnectionIsNecessary: Bool) -> Void) {
        let newState = State(enabled: isEnabled, resolvers: activeHermesResolvers)
        guard newState != initialState else {
            completionHandler(false)
            return
        }
        vpnStateConfiguration.getInfo { info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .immediate:
                completionHandler(false)
            case .withConnectionUpdate, .withReconnect:
                completionHandler(true)
            }
        }
        initialState = newState
    }

    func isReconnectionNecessaryFromNetShieldChange(completionHandler: @escaping (_ reconnectionIsNecessary: Bool) -> Void) {
        vpnStateConfiguration.getInfo { info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .immediate:
                completionHandler(false)
            case .withConnectionUpdate, .withReconnect:
                completionHandler(true)
            }
        }
    }

    func userEnablingHermesConfirmation() {
        netShieldPropertyProvider.netShieldType = .off
        hermesClient.setIsEnabled(true)
    }

    func validate(location: String) -> LocationValidation {
        guard !location.isEmpty else { return .empty }
        if activeHermesResolvers.contains(where: { $0.location == location }) {
            return .duplicate
        }
        return hermesClient.validateHermesLocation(location) ? .valid : .invalid
    }

    func addResolver(with location: String) -> Bool {
        switch validate(location: location) {
        case .duplicate:
            alert = .duplicate
            return false
        case .invalid:
            alert = .invalid
            return false
        default:
            do {
                let hermesResolver = try HermesResolver(ipAddress: location)
                return hermesClient.addHermesResolver(hermesResolver)
            } catch {
                alert = .unexpectedError
                return false
            }
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

    func moveResolvers(source: IndexSet, destination: Int) {
        var copy = activeHermesResolvers
        copy.move(fromOffsets: source, toOffset: destination)
        let diff = copy.difference(from: activeHermesResolvers)
        applyDiff(diff)
    }

    func openLearnMore() {
        @Dependency(\.linkOpener) var linkOpener
        linkOpener.open(.hermes)
    }
}

extension HermesSettingsViewModel.Alert {
    var title: String {
        switch self {
        case .hermesOnConflict:
            Localizable.hermesConflictHermesOnTitle
        case .netShieldOnConflict, .netShieldOnConflictAndShouldReconnect:
            Localizable.hermesConflictNetshieldOnTitle
        case .confirmChanges:
            Localizable.hermesApplyChangesAlertTitle
        case .duplicate, .invalid, .unexpectedError:
            Localizable.genericErrorTitle
        }
    }

    var message: String {
        switch self {
        case .duplicate:
            Localizable.hermesEntitiesFormValidationDuplicate
        case .invalid:
            Localizable.hermesEntitiesFormValidationEnterValidAddress
        case .unexpectedError:
            Localizable.hermesEntitiesFormValidationUnexpectedError
        case .hermesOnConflict:
            Localizable.hermesConflictHermesOnDescription
        case .netShieldOnConflict:
            Localizable.hermesConflictNetshieldOnDescription
        case .netShieldOnConflictAndShouldReconnect:
            Localizable.hermesConflictNetshieldOnAndShouldReconnectDescription
        case .confirmChanges:
            Localizable.hermesApplyChangesDescription
        }
    }
}

// Some alerts make sense within the SwiftUI view itself, and some such as the ones below when the view is dismissed
// So they cannot be displayed by the SwiftUI view since it won't be onscreen anymore, thus we expose UIAlertControllers
// that will be displayed by the parent container view controller.
extension HermesSettingsViewModel {
    func netShieldOnConflictAlertController(
        completionHandler: @escaping (_ shouldEnableNetShield: Bool) -> Void
    ) -> UIAlertController {
        let alertController = UIAlertController(
            title: Alert.netShieldOnConflict.title,
            message: Alert.netShieldOnConflict.message,
            preferredStyle: .alert
        )
        alertController.addAction(.init(title: Localizable.learnMore, style: .default, handler: { [weak self] _ in
            self?.openLearnMore()
            completionHandler(false)
        }))
        alertController.addAction(.init(title: Localizable.enable, style: .default, handler: { _ in completionHandler(true) }))
        alertController.addAction(.init(title: Localizable.cancel, style: .cancel, handler: { _ in completionHandler(false) }))
        return alertController
    }

    func netShieldOnConflictAndShouldReconnectAlertController(
        completionHandler: @escaping (_ shouldEnableNetShield: Bool, _ shouldReconnect: Bool) -> Void
    ) -> UIAlertController {
        let alertController = UIAlertController(
            title: Alert.netShieldOnConflict.title,
            message: Alert.netShieldOnConflict.message,
            preferredStyle: .alert
        )
        alertController.addAction(.init(title: Localizable.learnMore, style: .default, handler: { [weak self] _ in
            self?.openLearnMore()
            completionHandler(false, false)
        }))
        alertController.addAction(.init(title: Localizable.hermesConflictNetshieldOnEnableAndReconnect, style: .default, handler: { _ in completionHandler(true, true) }))
        alertController.addAction(.init(title: Localizable.cancel, style: .cancel, handler: { _ in completionHandler(false, false) }))
        return alertController
    }

    func reconnectionAlertController(
        completionHandler: @escaping (_ shouldReconnect: Bool) -> Void
    ) -> UIAlertController {
        let alertController = UIAlertController(
            title: Alert.confirmChanges.title,
            message: Alert.confirmChanges.message,
            preferredStyle: .alert
        )
        alertController.addAction(.init(title: Localizable.continue, style: .default, handler: { _ in completionHandler(true) }))
        alertController.addAction(.init(title: Localizable.cancel, style: .cancel, handler: { _ in completionHandler(false) }))
        return alertController
    }
}
