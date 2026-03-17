//
//  Created on 11/02/2022.
//
//  Copyright (c) 2022 Proton AG
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

import ProtonCoreUtilities
import SharedViews
import Strings
import SwiftUI

public enum ModalType {
    case welcomePlus(numberOfServers: Int, numberOfDevices: Int, numberOfCountries: Int)
    case welcomeUnlimited
    case welcomeFallback
    case onboardingWelcome // new onboarding screen 1
    case onboardingGetStarted // new onboarding screen 2

    public func modalModel() -> ModalModel {
        ModalModel(
            title: title(),
            subtitle: subtitle(),
            features: features(),
            primaryButtonTitle: primaryButtonTitle(),
            secondaryButtonTitle: secondaryButtonTitle()
        )
    }
}

public extension ModalType {
    @ViewBuilder
    func artImage() -> some View {
        switch self {
        case .welcomePlus:
            Asset.welcomePlus.swiftUIImage
        case .welcomeUnlimited:
            Asset.welcomeUnlimited.swiftUIImage
        case .welcomeFallback:
            Asset.welcomeFallback.swiftUIImage
        case .onboardingWelcome:
            Asset.welcomeRedesigned.swiftUIImage
        case .onboardingGetStarted:
            Asset.getStarted.swiftUIImage
        }
    }

    var showUpgradeButton: Bool {
        switch self {
        case .welcomeFallback, .welcomeUnlimited, .welcomePlus:
            false
        default:
            true
        }
    }

    var shouldVerticallyCenterContent: Bool {
        switch self {
        case .onboardingWelcome, .onboardingGetStarted:
            false
        default:
            true
        }
    }

    var multipleStepsModal: (stepCount: Int, totalStepCount: Int)? {
        switch self {
        case .onboardingWelcome:
            (1, 2)
        case .onboardingGetStarted:
            (2, 2)
        default:
            nil
        }
    }
}

private extension ModalType {
    func primaryButtonTitle() -> String {
        switch self {
        case .onboardingWelcome:
            Localizable.continue
        case .onboardingGetStarted, .welcomeFallback, .welcomeUnlimited, .welcomePlus:
            Localizable.modalsCommonGetStarted
        }
    }

    func secondaryButtonTitle() -> String? {
        Localizable.notNow
    }

    func title() -> String {
        switch self {
        case .welcomePlus:
            Localizable.welcomeUpgradeTitlePlus
        case .welcomeUnlimited:
            Localizable.welcomeUpgradeTitleUnlimited
        case .welcomeFallback:
            Localizable.welcomeUpgradeTitleFallback
        case .onboardingWelcome:
            Localizable.welcomeToProtonTitle
        case .onboardingGetStarted:
            Localizable.settingsTitleCensorship
        }
    }

    func subtitle() -> ModalModel.Subtitle? {
        switch self {
        case .welcomePlus:
            return .init(text: Localizable.welcomeUpgradeSubtitlePlus, boldText: [])
        case .welcomeUnlimited:
            #if os(iOS)
                return .init(
                    text: Localizable.welcomeUpgradeSubtitleUnlimitedMarkdown,
                    boldText: [Localizable.welcomeUpgradeSubtitleUnlimitedBold]
                )
            #else
                return .init(text: Localizable.welcomeUpgradeSubtitleUnlimited, boldText: [])
            #endif
        case .welcomeFallback:
            return .init(text: Localizable.welcomeUpgradeSubtitleFallback)
        case .onboardingWelcome:
            return .init(text: Localizable.welcomeToProtonSubtitle)
        case .onboardingGetStarted:
            return nil
        }
    }

    func features() -> [Feature] {
        switch self {
        case let .welcomePlus(numberOfServers, numberOfDevices, numberOfCountries):
            [
                .welcomeNewServersCountries(numberOfServers, numberOfCountries),
                .welcomeAdvancedFeatures,
                .welcomeDevices(numberOfDevices),
            ]
        case .welcomeUnlimited:
            []
        case .welcomeFallback:
            []
        case .onboardingWelcome:
            [.banner]
        case .onboardingGetStarted:
            [
                .toggle(
                    id: .statistics,
                    title: Localizable.onboardingGetStartedStatisticsToggleTitle,
                    subtitle: Localizable.onboardingGetStartedStatisticsToggleSubtitle,
                    state: true
                ),
                .toggle(
                    id: .crashes,
                    title: Localizable.onboardingGetStartedCrashesToggleTitle,
                    subtitle: Localizable.onboardingGetStartedCrashesToggleSubtitle,
                    state: true
                ),
            ]
        }
    }
}
