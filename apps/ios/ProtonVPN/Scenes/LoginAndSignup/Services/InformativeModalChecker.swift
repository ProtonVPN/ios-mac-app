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

/// The logic for showing or not showing the informative modal for Russian users.
/// - Don't worsen the non-Russian experience of the app
/// - Try our best to show the modal to users in Russia
final class InformativeModalChecker {

    func presentInformativeViewController(on viewController: UIViewController ) {
        guard shouldPresentInformativeModal() else {
            return
        }
        let informativeViewController = ModalsFactory(colors: UpsellColors()).informativeViewController {
            viewController.dismiss(animated: true)
        }
        informativeViewController.modalPresentationStyle = .fullScreen
        viewController.present(informativeViewController, animated: false)
        isLocationInRussia { isInRussia in
            if isInRussia {
                informativeViewController.setIsLoading(false)
            } else {
                viewController.dismiss(animated: true)
            }
        }
    }

    private func shouldPresentInformativeModal() -> Bool {
        let networkProviders = CTTelephonyNetworkInfo().serviceSubscriberCellularProviders
        let isoCountryCode = networkProviders?.first?.value.isoCountryCode

        let isLocaleRU = Locale.current.languageCode == "RU" && Locale.current.regionCode == "RU"

        if let homeCountryCode = isoCountryCode {
            if homeCountryCode == "RU" {
                return true
            } else {
                return false // false negative: A foreign user travels to Russia, won't get the modal
            }
        } else if isLocaleRU {
            return true
        } else {
            return false // false negative: User in Russia with non-Russian sim card (or without sim card) that set the locale to other then RU will not see the modal
        }
    }

    func isLocationInRussia(callback: (Bool) -> Void) {
        locationCheck { result in
            switch result {
            case .success(let location):
                if location == "RU" {
                    callback(true)
                    // show modal <- we're sure user is in Russia
                } else {
                    callback(false)
                    // don't show <- we're sure user is not in Russia
                }
            case .failure(let error):
                switch error {
                case .network:
                    callback(false)
                    // don't show <- disconnected from network
                case .timeout:
                    callback(true)
                    // show error <- blocked by network provider
                }
            }
        }
    }

    private enum LocationError: Error {
        case timeout
        case network
    }

    private func locationCheck(completion: (Result<String, LocationError>) -> Void) {
        completion(.success("RU"))
    }
}
