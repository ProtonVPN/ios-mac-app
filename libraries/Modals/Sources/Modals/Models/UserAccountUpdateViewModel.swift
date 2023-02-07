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

public enum UserAccountUpdateViewModel {
    case subscriptionDowngradedReconnecting(numberOfCountries: Int, numberOfDevices: Int, fromServer: (String, Image), toServer: (String, Image))
    case subscriptionDowngraded(numberOfCountries: Int, numberOfDevices: Int)
    case pendingInvoicesReconnecting(fromServer: (String, Image), toServer: (String, Image))
    case pendingInvoices
    case reachedDeviceLimit
    case reachedDevicePlanLimit(planName: String, numberOfDevices: Int)
}

extension UserAccountUpdateViewModel {
    public var fromServerTitle: String { LocalizedString.fromServerTitle }
    public var toServerTitle: String { LocalizedString.toServerTitle }

    public var primaryButtonTitle: String {
        switch self {
        case .subscriptionDowngraded, .subscriptionDowngradedReconnecting:
            return LocalizedString.upgradeAgain
        case .pendingInvoicesReconnecting, .pendingInvoices:
            return LocalizedString.updateBilling
        case .reachedDeviceLimit:
            return LocalizedString.newPlansBrandGotIt
        case .reachedDevicePlanLimit:
            return LocalizedString.modalsGetPlus
        }
    }

    public var secondaryButtonTitle: String? {
        switch self {
        case .reachedDeviceLimit:
            return nil
        default:
            return LocalizedString.upgradeNoThanks
        }
    }

    public var options: [String]? {
        switch self {
        case .subscriptionDowngradedReconnecting(let numberOfCountries, let numberOfDevices, _, _),
                .subscriptionDowngraded(let numberOfCountries, let numberOfDevices):
            return [LocalizedString.subscriptionUpgradeOption1(numberOfCountries),
                    LocalizedString.subscriptionUpgradeOption2(numberOfDevices),
                    LocalizedString.subscriptionUpgradeOption3]
        default:
            return nil
        }
    }

    public var title: String? {
        switch self {
        case .subscriptionDowngradedReconnecting, .subscriptionDowngraded:
            return LocalizedString.subscriptionExpiredTitle
        case .pendingInvoicesReconnecting, .pendingInvoices:
            return LocalizedString.delinquentTitle
        case .reachedDevicePlanLimit, .reachedDeviceLimit:
            return LocalizedString.maximumDeviceTitle
        }
    }

    public var subtitle: String? {
        switch self {
        case .subscriptionDowngradedReconnecting:
            return LocalizedString.subscriptionExpiredReconnectionDescription
        case .subscriptionDowngraded:
            return LocalizedString.subscriptionExpiredDescription
        case .pendingInvoicesReconnecting:
            return LocalizedString.delinquentReconnectionDescription
        case .pendingInvoices:
            return LocalizedString.delinquentDescription
        case .reachedDevicePlanLimit(let planName, let numberOfDevices):
            return LocalizedString.maximumDevicePlanLimitPart1(planName) + LocalizedString.maximumDevicePlanLimitPart2(numberOfDevices)
        case .reachedDeviceLimit:
            return LocalizedString.maximumDeviceLimit
        }
    }

    public var image: Image? {
        switch self {
        case .reachedDevicePlanLimit:
            return Asset.maximumDeviceLimitUpsell.image
        case .reachedDeviceLimit:
            return Asset.maximumDeviceLimitWarning.image
        default:
            return nil
        }
    }

    public var checkmark: Image? {
        Asset.checkmarkCircle.image
    }

    public var fromServer: (String, Image)? {
        switch self {
        case .pendingInvoicesReconnecting(let fromServer, _):
            return fromServer
        case .subscriptionDowngradedReconnecting(_, _, let fromServer, _):
            return fromServer
        default:
            return nil
        }
    }

    public var toServer: (String, Image)? {
        switch self {
        case .pendingInvoicesReconnecting(_, let toServer):
            return toServer
        case .subscriptionDowngradedReconnecting(_, _, _, let toServer):
            return toServer
        default:
            return nil
        }
    }
}
