//
//  Created on 2/8/22.
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

import Foundation
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

public enum Feature: Hashable, Identifiable {
    public enum ToggleID: Hashable, Identifiable {
        public var id: Self { self }

        case statistics
        case crashes
    }

    public var id: Self { self }

    case welcomeNewServersCountries(Int, Int)
    case welcomeAdvancedFeatures
    case welcomeDevices(Int)
    case banner
    case toggle(id: ToggleID, title: String, subtitle: String, state: Bool)
}

extension Feature: Equatable {}

public extension Feature {
    // swiftlint:disable:next cyclomatic_complexity
    func title() -> String? {
        switch self {
        case let .welcomeNewServersCountries(servers, countries):
            Localizable.welcomeScreenFeatureServersCountries(servers, countries)
        case .welcomeAdvancedFeatures:
            Localizable.welcomeUpgradeAdvancedFeatures
        case let .welcomeDevices(devices):
            Localizable.welcomeScreenFeatureDevices(devices)
        case .banner:
            nil
        case .toggle:
            nil
        }
    }

    func boldTitleElements() -> [String] {
        switch self {
        default:
            []
        }
    }

    var image: ModalsShared.ImageAsset.Image? {
        switch self {
        case .welcomeNewServersCountries:
            IconProvider.globe
        case .welcomeAdvancedFeatures:
            IconProvider.sliders
        case .welcomeDevices:
            IconProvider.locks
        case .banner:
            IconProvider.play
        case .toggle:
            nil
        }
    }
}
