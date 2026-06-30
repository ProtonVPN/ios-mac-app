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

import Dependencies
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Modals
import Payments
import Strings
import Telemetry
import UIKit
import VPNAppCore

/// Presents upsell and welcome modals on iOS
final class IosUpsellManager {
    @Dependency(\.windowService) private var windowService
    @Dependency(\.serverRepository) private var serverRepository

    private lazy var navigationService: NavigationService? =
        (Container.sharedContainer as? NavigationServiceFactory)?.makeNavigationService()

    private let paymentsFlowCoordinator = PaymentsFlowCoordinator()
    private var oneClickIapVC: UIViewController?

    @MainActor
    func present(_ source: UpsellModalSource) {
        guard let upsellModalType = upsellModalType(for: source) else {
            log.warning("No upsell modal available for source \(source) on iOS", category: .ui)
            return
        }
        showUpsell(modalSource: source, upsellModalType: upsellModalType)
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
        let viewController = ModalsFactory().modalViewController(modalType: modalType, primaryAction: { [weak self] in
            self?.windowService.dismissModal(nil)
        })
        viewController.modalPresentationStyle = .overFullScreen
        windowService.present(modal: viewController)
    }

    @MainActor
    private func showUpsell(modalSource: UpsellModalSource, upsellModalType: Payments.UpsellModalType) {
        let viewController = paymentsFlowCoordinator.makeViewController(
            request: .upsell(upsellModalType)
        ) { [weak self] event in
            guard let self else { return }
            switch event {
            case .completed, .dismissed:
                windowService.dismissModal(nil)
            case let .engaged(_, purchaseType):
                let upsellData: UpsellData = if purchaseType == .web {
                    .webIntro(modalSource: modalSource, newPlanName: nil)
                } else {
                    .init(
                        modalSource: modalSource,
                        newPlanName: nil,
                        reference: nil,
                        cycle: nil,
                        flowType: .oneClick
                    )
                }
                AppEvent.userEngagedWithUpsellAlert.post(upsellData)
            case .createAccountFirstRequested:
                guard let oneClickIapVC else { return }
                navigationService?.presentSignUp(over: oneClickIapVC, flow: .credentiallessUpsell)
            }
        }

        viewController.modalPresentationStyle = .overFullScreen
        oneClickIapVC = viewController
        windowService.present(modal: viewController)
        AppEvent.upsellAlertWasDisplayed.post(modalSource)
    }

    /// Maps the platform-agnostic upsell source to the iOS upsell modal type.
    /// Returns `nil` for sources that have no upsell surface on iOS.
    private func upsellModalType(for source: UpsellModalSource) -> Payments.UpsellModalType? {
        switch source {
        case .countries:
            .allCountries(
                numberOfServers: serverRepository.roundedServerCount,
                numberOfCountries: serverRepository.countryCount()
            )
        case .netShield:
            .netShield
        case .secureCore:
            .secureCore
        case .moderateNat:
            .moderateNAT
        case .allowLan:
            .customization
        case .profiles:
            .profiles
        case .vpnAccelerator:
            .vpnAccelerator
        case .tor:
            .torOverVPN
        case .hermes:
            .hermes
        case .portForwarding, .splitTunneling, .promoOffer:
            nil
        }
    }
}

// MARK: - Live dependency

extension UpsellManager: @retroactive DependencyKey {
    public static let liveValue: UpsellManager = {
        let presenter = IosUpsellManager()
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
