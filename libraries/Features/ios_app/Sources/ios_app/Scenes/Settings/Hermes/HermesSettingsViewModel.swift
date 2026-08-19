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

import Connection
import Dependencies
import Domain
import Hermes
import Settings
import Sharing
import Strings
import SwiftUI
import VPNAppCore

@Observable
final class HermesSettingsViewModel {
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
        case duplicate
        case invalid
        case unexpectedError
    }

    private struct State: Equatable {
        let enabled: Bool
        let resolvers: [HermesResolver]
    }

    @ObservationIgnored
    @SharedReader var activeHermesResolvers: [HermesResolver]

    @ObservationIgnored
    @SharedReader var isEnabled: Bool

    @ObservationIgnored
    @Dependency(\.hermesClient) private var hermesClient

    var isNetShieldEnabled: Bool {
        netShieldPropertyProvider.getNetShieldType() != .off
    }

    var alert: Alert?

    @ObservationIgnored
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @ObservationIgnored
    @SharedReader(.connectionState) private var connectionState: ConnectionState

    private var initialState: State

    init() {
        @Dependency(\.hermesClient) var hermesClient
        let hermesIsEnabled = hermesClient.isEnabled()
        let resolvers = hermesClient.activeHermesResolvers()
        self._isEnabled = hermesIsEnabled
        self._activeHermesResolvers = hermesClient.activeHermesResolvers()
        self.initialState = .init(enabled: hermesIsEnabled.wrappedValue, resolvers: resolvers.wrappedValue)
    }

    func onAppear() {
        initialState = State(enabled: isEnabled, resolvers: activeHermesResolvers)
    }

    func setIsEnabled(_ newValue: Bool, force: Bool = false) {
        if force {
            hermesClient.setIsEnabled(newValue)
            return
        }
        if isNetShieldEnabled, newValue {
            alert = .hermesOnConflict
        } else {
            hermesClient.setIsEnabled(newValue)
        }
    }

    /// How a pending Hermes (enabled flag or resolver list) change should be applied, or `nil` if nothing changed
    /// since the view last appeared.
    func hermesChangeAvailability(completionHandler: @escaping (_ availability: VpnFeatureChangeState?) -> Void) {
        let newState = State(enabled: isEnabled, resolvers: activeHermesResolvers)
        guard newState != initialState else {
            completionHandler(nil)
            return
        }
        initialState = newState
        completionHandler(VpnFeatureChangeState(connectionState: connectionState))
    }

    func userEnablingHermesConfirmation() {
        netShieldPropertyProvider.setNetShieldType(.off)
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
        case .netShieldOnConflict:
            Localizable.hermesConflictNetshieldOnTitle
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
}
