//
//  Created on 26/06/2026 by Max Kupetskyi.
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

import AppKit
import Dependencies
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Modals
import Payments
import Strings
import VPNAppCore

/// Presents upsell and welcome modals on macOS
final class MacUpsellManager {
    @Dependency(\.windowService) private var windowService
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.sessionService) private var sessionService
    @Dependency(\.linkOpener) private var linkOpener

    @MainActor
    func present(_ source: UpsellModalSource) {
        guard let upsellModalType = upsellModalType(for: source) else {
            log.warning("No upsell modal available for source \(source) on macOS", category: .ui)
            return
        }

        AppEvent.upsellAlertWasDisplayed.post(source)

        let upsellViewController = LegacyUpsellFactory.upsellViewController(
            upsellModalType: upsellModalType,
            upgradeAction: upgradeAction(modalSource: source),
            skipAction: {},
            showsCloseButton: false
        )

        windowService.presentKeyModal(viewController: upsellViewController, activatingApp: false)
    }

    @MainActor
    func presentWelcome(_ plan: WelcomeScreenPlan) {
        let modalType: ModalType = switch plan {
        case .fallback:
            .welcomeFallback
        case .unlimited:
            .welcomeUnlimited
        case let .plus(numberOfServers, numberOfDevices, numberOfCountries):
            .welcomePlus(
                numberOfServers: numberOfServers,
                numberOfDevices: numberOfDevices,
                numberOfCountries: numberOfCountries
            )
        }

        AppEvent.upsellAlertWasDisplayed.post(nil)

        let viewController = ModalsFactory.modalViewController(
            modalType: modalType,
            upgradeAction: upgradeAction(modalSource: nil),
            continueAction: {}
        )

        windowService.presentKeyModal(viewController: viewController, activatingApp: false)
    }

    private func upgradeAction(modalSource: UpsellModalSource?) -> () -> Void {
        { [weak self] in
            Task { [weak self] in
                guard let url = await self?.sessionService.getPlanSession(mode: .upgrade) else {
                    return
                }
                AppEvent.userEngagedWithUpsellAlert.post(modalSource)
                self?.linkOpener.open(url)
            }
        }
    }

    private func upsellModalType(for source: UpsellModalSource) -> UpsellModalType? {
        switch source {
        case .countries:
            .allCountries(
                numberOfServers: serverRepository.roundedServerCount,
                numberOfCountries: serverRepository.countryCount()
            )
        case .moderateNat:
            .moderateNAT
        case .secureCore:
            .secureCore
        case .netShield:
            .netShield
        case .portForwarding:
            .portForwarding
        case .profiles:
            .profiles
        case .vpnAccelerator:
            .vpnAccelerator
        case .allowLan:
            .customization
        case .hermes:
            .hermes
        case .splitTunneling:
            .plutonium
        case .tor, .promoOffer:
            nil
        }
    }
}

// MARK: - Live dependency

extension UpsellManager: @retroactive DependencyKey {
    public static let liveValue: UpsellManager = {
        let presenter = MacUpsellManager()
        return UpsellManager(
            present: { source in
                executeOnUIThread {
                    MainActor.assumeIsolated {
                        presenter.present(source)
                    }
                }
            },
            presentWelcome: { plan in
                executeOnUIThread {
                    MainActor.assumeIsolated {
                        presenter.presentWelcome(plan)
                    }
                }
            }
        )
    }()
}
