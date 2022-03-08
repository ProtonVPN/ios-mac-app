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
    @IBOutlet private weak var freeUserSwitch: UISwitch!

    private var coordinator: SearchCoordinator?
    private let modals = ModalsFactory(colors: Colors(background: .black, text: .white, brand: UIColor(red: 77/255, green: 163/255, blue: 88/255, alpha: 1), weakText: UIColor(red: 156/255, green: 160/255, blue: 170/255, alpha: 1)))

    override func viewDidLoad() {
        super.viewDidLoad()        

        navigationController?.navigationBar.barTintColor = UIColor.black
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.isTranslucent = false

        title = "Search sample app"
    }

    @IBAction private func searchTapped(_ sender: Any) {
        coordinator = SearchCoordinator(configuration: Configuration(colors: Colors(background: .black, text: .white, brand: UIColor(red: 77/255, green: 163/255, blue: 88/255, alpha: 1), weakText: UIColor(red: 156/255, green: 160/255, blue: 170/255, alpha: 1), secondaryBackground: UIColor(red: 37/255, green: 39/255, blue: 44/255, alpha: 1)), constants: Constants(numberOfCountries: 61), isFreeUser: freeUserSwitch.isOn))
        coordinator?.delegate = self
        coordinator?.start(navigationController: self.navigationController!, data: createData())
    }

    private func createData() -> [CountryItemViewModel] {
        let tier = freeUserSwitch.isOn ? ServerTier.free : ServerTier.plus

        return [
            CountryItemViewModel(country: "Switzerland", servers: [
                ServerTier.basic: [
                    ServerItemViewModel(server: "CH#1", city: "Geneva"),
                    ServerItemViewModel(server: "CH#2", city: "Geneva")
                ],
                tier: [
                    ServerItemViewModel(server: "CH#3", city: "Zurich")
                ]
            ]),
            CountryItemViewModel(country: "United States", servers: [
                ServerTier.basic: [
                    ServerItemViewModel(server: "NY#1", city: "New York"),
                    ServerItemViewModel(server: "NY#2", city: "New York")
                ],
                tier: [
                    ServerItemViewModel(server: "WA#3", city: "Seatle")
                ]
            ]),
            CountryItemViewModel(country: "Czechia", servers: [
                ServerTier.basic: [
                    ServerItemViewModel(server: "CZ#1", city: "Prague"),
                    ServerItemViewModel(server: "CZ#2", city: "Brno")
                ],
                tier: [
                    ServerItemViewModel(server: "CZ#3", city: "Prague")
                ]
            ])
        ]
    }
}

extension ViewController: SearchCoordinatorDelegate {
    func userDidRequestPlanPurchase() {
        let upsell = UpsellType.allCountries(numberOfDevices: 10, numberOfServers: 1600, numberOfCountries: 61)
        let upsellViewController = modals.upsellViewController(upsellType: upsell)
        navigationController?.present(upsellViewController, animated: true, completion: nil)
    }

    func userDidSelectCountry(model: CountryViewModel) {

    }
}
