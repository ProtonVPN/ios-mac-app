//
//  Created on 28/04/2022.
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
import Theme

public enum UserAccountUpdateViewModel {
    case subscriptionDowngradedReconnecting(numberOfCountries: Int, numberOfDevices: Int, fromServer: (String, Image), toServer: (String, Image))
    case subscriptionDowngraded(numberOfCountries: Int, numberOfDevices: Int)
    case pendingInvoicesReconnecting(fromServer: (String, Image), toServer: (String, Image))
    case pendingInvoices
    case reachedDeviceLimit
    case reachedDevicePlanLimit(planName: String, numberOfDevices: Int)
}

extension UserAccountUpdateViewModel {
    public var fromServerTitle: String { Localizable.fromServerTitle }
    public var toServerTitle: String { Localizable.toServerTitle }

    public var primaryButtonTitle: String {
        switch self {
        case .subscriptionDowngraded, .subscriptionDowngradedReconnecting:
            Localizable.upgradeAgain
        case .pendingInvoicesReconnecting, .pendingInvoices:
            Localizable.updateBilling
        case .reachedDeviceLimit:
            Localizable.newPlansBrandGotIt
        case .reachedDevicePlanLimit:
            Localizable.modalsGetPlus
        }
    }

    public var secondaryButtonTitle: String? {
        switch self {
        case .reachedDeviceLimit:
            nil
        default:
            Localizable.noThanks
        }
    }

    public var options: [String]? {
        switch self {
        case let .subscriptionDowngradedReconnecting(numberOfCountries, numberOfDevices, _, _),
             let .subscriptionDowngraded(numberOfCountries, numberOfDevices):
            [Localizable.subscriptionUpgradeOption1(numberOfCountries),
             Localizable.subscriptionUpgradeOption2(numberOfDevices),
             Localizable.subscriptionUpgradeOption3]
        default:
            nil
        }
    }

    public var title: String? {
        switch self {
        case .subscriptionDowngradedReconnecting, .subscriptionDowngraded:
            Localizable.subscriptionExpiredTitle
        case .pendingInvoicesReconnecting, .pendingInvoices:
            Localizable.delinquentTitle
        case .reachedDevicePlanLimit, .reachedDeviceLimit:
            Localizable.maximumDeviceTitle
        }
    }

    public var subtitle: String? {
        switch self {
        case .subscriptionDowngradedReconnecting:
            Localizable.subscriptionExpiredReconnectionDescription
        case .subscriptionDowngraded:
            Localizable.subscriptionExpiredDescription
        case .pendingInvoicesReconnecting:
            Localizable.delinquentReconnectionDescription
        case .pendingInvoices:
            Localizable.delinquentDescription
        case let .reachedDevicePlanLimit(planName, numberOfDevices):
            Localizable.maximumDevicePlanLimitPart1(planName) + Localizable.maximumDevicePlanLimitPart2(numberOfDevices)
        case .reachedDeviceLimit:
            Localizable.maximumDeviceLimit
        }
    }

    public var image: Image? {
        switch self {
        case .reachedDevicePlanLimit:
            Asset.maximumDeviceLimitUpsell.image
        case .reachedDeviceLimit:
            Asset.maximumDeviceLimitWarning.image
        default:
            nil
        }
    }

    public var checkmark: Image? {
        IconProvider.checkmarkCircleFilled
    }

    public var fromServer: (String, Image)? {
        switch self {
        case let .pendingInvoicesReconnecting(fromServer, _):
            fromServer
        case let .subscriptionDowngradedReconnecting(_, _, fromServer, _):
            fromServer
        default:
            nil
        }
    }

    public var toServer: (String, Image)? {
        switch self {
        case let .pendingInvoicesReconnecting(_, toServer):
            toServer
        case let .subscriptionDowngradedReconnecting(_, _, _, toServer):
            toServer
        default:
            nil
        }
    }
}
