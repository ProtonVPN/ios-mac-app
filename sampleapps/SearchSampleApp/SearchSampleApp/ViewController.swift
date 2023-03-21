//
//  Created on 02.03.2022.
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
import Modals
import Modals_iOS
import Search

final class ViewController: UIViewController {
    @IBOutlet private weak var userTierSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var modeSegmentedControl: UISegmentedControl!

    private var coordinator: SearchCoordinator = {
        return SearchCoordinator(configuration: Configuration(constants: Constants(numberOfCountries: 61)), storage: Storage())
    }()
    private let modals: ModalsFactory = {
        return ModalsFactory()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()        

        navigationController?.navigationBar.barTintColor = UIColor.black
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.isTranslucent = false

        title = "Search sample app"
        coordinator.delegate = self

        modeSegmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
    }

    @IBAction private func searchTapped(_ sender: Any) {
        coordinator.start(navigationController: self.navigationController!, data: createData(), mode: createMode())
    }

    @objc private func modeChanged() {
        userTierSegmentedControl.isEnabled = modeSegmentedControl.selectedSegmentIndex == 0
    }

    private func createMode() -> SearchMode {
        switch modeSegmentedControl.selectedSegmentIndex {
        case 0:
            return .standard(createTier())
        default:
            return .secureCore
        }
    }

    private func createTier() -> UserTier {
        switch userTierSegmentedControl.selectedSegmentIndex {
        case 0:
            return .free
        default:
            return .plus
        }
    }

    private func createData(forceTier: ServerTier? = nil) -> [CountryItemViewModel] {
        let mode = createMode()
        let tier = forceTier ?? (createTier() == UserTier.free ? ServerTier.free : ServerTier.plus)
        let isSecureCoreCountry = mode == .secureCore
        let entryCountryName: String? = mode == .secureCore ? "Italy" : nil

        let switzerlandServers: [ServerTier : [ServerViewModel]] = {
            let free = [
                ServerItemViewModel(server: "CH#1", city: "Geneva", countryName: "Switzerland", isUsersTierTooLow: tier == ServerTier.free, entryCountryName: entryCountryName),
                ServerItemViewModel(server: "CH#2", city: "Geneva", countryName: "Switzerland", isUsersTierTooLow: tier == ServerTier.free, entryCountryName: entryCountryName)
            ]
            switch tier {
            case .free:
                return [ServerTier.free: free]
            case .plus:
                return [
                    ServerTier.free: free,
                    ServerTier.plus: [
                        ServerItemViewModel(server: "CH#3", city: "Zurich", countryName: "Switzerland", entryCountryName: entryCountryName)
                    ]
                ]
            }
        }()

        let usServers: [ServerTier : [ServerViewModel]] = {
            let free = [
                ServerItemViewModel(server: "NY#1", city: "New York", countryName: "United States", isUsersTierTooLow: tier == ServerTier.free, entryCountryName: entryCountryName),
                ServerItemViewModel(server: "NY#2", city: "New York", countryName: "United States", isUsersTierTooLow: tier == ServerTier.free, entryCountryName: entryCountryName)
            ]
            switch tier {
            case .free:
                return [ServerTier.free: free]
            case .plus:
                return [
                    ServerTier.free: free,
                    ServerTier.plus: [
                        ServerItemViewModel(server: "WA#3", city: "Seatle", countryName: "United States", entryCountryName: entryCountryName)
                    ]
                ]
            }
        }()

        let czechiaServers: [ServerTier : [ServerViewModel]] = {
            let free = [
                ServerItemViewModel(server: "CZ#1", city: "Prague", countryName: "Czechia", isUsersTierTooLow: tier == ServerTier.free, entryCountryName: entryCountryName),
                ServerItemViewModel(server: "CZ#2", city: "Brno", countryName: "Czechia", isUsersTierTooLow: tier == ServerTier.free, entryCountryName: entryCountryName)
            ]
            switch tier {
            case .free:
                return [ServerTier.free: free]
            case .plus:
                return [
                    ServerTier.free: free,
                    ServerTier.plus: [
                        ServerItemViewModel(server: "CZ#3", city: "Prague", countryName: "Czechia", entryCountryName: entryCountryName)
                    ]
                ]
            }
        }()

        return [
            CountryItemViewModel(country: "Switzerland", servers: switzerlandServers, isSecureCoreCountry: isSecureCoreCountry),
            CountryItemViewModel(country: "United States", servers: usServers, isSecureCoreCountry: isSecureCoreCountry),
            CountryItemViewModel(country: "Czechia", servers: czechiaServers, isSecureCoreCountry: isSecureCoreCountry)
        ]
    }
}

extension ViewController: SearchCoordinatorDelegate {
    func userDidRequestPlanPurchase() {
        let upsell = UpsellType.allCountries(numberOfDevices: 10, numberOfServers: 1600, numberOfCountries: 61)
        let upsellViewController = modals.upsellViewController(upsellType: upsell)
        upsellViewController.delegate = self
        navigationController?.present(upsellViewController, animated: true, completion: nil)
    }

    func userDidSelectCountry(model: CountryViewModel) {

    }
}

extension ViewController: UpsellViewControllerDelegate {
    func userDidTapNext() {

    }

    func userDidDismissUpsell() {
        
    }

    func shouldDismissUpsell() -> Bool {
        return true
    }

    func userDidRequestPlus() {
        coordinator.reload(data: createData(forceTier: .plus), mode: createMode())
        navigationController?.dismiss(animated: true, completion: nil)
    }
}
