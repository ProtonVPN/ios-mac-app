//
//  Created on 07/07/2022.
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

import UIKit
import Modals_iOS
import CoreTelephony
import vpncore

/// The logic for showing or not showing the informative modal for Russian users.
/// - Don't worsen the non-Russian experience of the app
/// - Try our best to show the modal to users in Russia
final class InformativeModalChecker {
    typealias Factory = PropertiesManagerFactory

    private let propertiesManager: PropertiesManagerProtocol

    init(factory: Factory) {
        propertiesManager = factory.makePropertiesManager()
    }

    func presentInformativeViewController(on viewController: UIViewController ) {
        guard shouldPresentInformativeModal() else {
            return
        }
        let informativeViewController = ModalsFactory(colors: UpsellColors()).informativeViewController {
            viewController.dismiss(animated: true)
        }
        informativeViewController.modalPresentationStyle = .fullScreen
        viewController.present(informativeViewController, animated: false)
    }

    private func shouldPresentInformativeModal() -> Bool {
        let expectedCountryCode = "RU"

        let networkProviders = CTTelephonyNetworkInfo().serviceSubscriberCellularProviders
        let isoCountryCode = networkProviders?.first?.value.isoCountryCode?.uppercased()
        let isLanguageCodeRU = Locale.current.languageCode?.uppercased() == expectedCountryCode
        let isRegionCodeRU = Locale.current.regionCode?.uppercased() == expectedCountryCode
        let isLocaleRU = isLanguageCodeRU && isRegionCodeRU

        if let userLocation = propertiesManager.userLocation?.country.uppercased() {
            if userLocation == expectedCountryCode {
                return true // We're quite sure the user is in Russia
            } else {
                return false // We're quite sure the user is not in Russia
            }
        }
        if let homeCountryCode = isoCountryCode {
            if homeCountryCode == expectedCountryCode {
                return true // The sim card is from Russia, but the user can be anywhere, will still get the modal
            } else {
                return false // possible false negative: A foreign user travels to Russia, won't get the modal
            }
        }
        if isLocaleRU {
            return true // possible false positive: Anyone located anywhere can set these to Russia and they'll see the modal
        } else {
            return false // possible false negative: User in Russia with non-Russian sim card (or without sim card) that set the locale to other then RU will not see the modal
        }
    }
}
