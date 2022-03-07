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
import Search

final class ViewController: UIViewController {
    private var coordinator: SearchCoordinator?

    private let data: [CountryItemViewModel] = [
        CountryItemViewModel(country: "Switzerland", servers: [
            ServerTier.basic: [
                ServerItemViewModel(server: "CH#1", city: "Geneva"),
                ServerItemViewModel(server: "CH#2", city: "Geneva")
            ],
            ServerTier.plus: [
                ServerItemViewModel(server: "CH#3", city: "Zurich")
            ]
        ]),
        CountryItemViewModel(country: "United States", servers: [
            ServerTier.basic: [
                ServerItemViewModel(server: "NY#1", city: "New York"),
                ServerItemViewModel(server: "NY#2", city: "New York")
            ],
            ServerTier.plus: [
                ServerItemViewModel(server: "WA#3", city: "Seatle")
            ]
        ]),
        CountryItemViewModel(country: "Czechia", servers: [
            ServerTier.basic: [
                ServerItemViewModel(server: "CZ#1", city: "Prague"),
                ServerItemViewModel(server: "CZ#2", city: "Brno")
            ],
            ServerTier.plus: [
                ServerItemViewModel(server: "CZ#3", city: "Prague")
            ]
        ])
    ]

    override func viewDidLoad() {
        super.viewDidLoad()        

        navigationController?.navigationBar.barTintColor = UIColor.black
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.isTranslucent = false

        view.backgroundColor = .black
    }

    @IBAction private func searchTapped(_ sender: Any) {
        coordinator = SearchCoordinator(configuration: Configuration(colors: Colors(background: .black, text: .white, brand: UIColor(red: 77/255, green: 163/255, blue: 88/255, alpha: 1), weakText: UIColor(red: 156/255, green: 160/255, blue: 170/255, alpha: 1))))
        coordinator?.delegate = self
        coordinator?.start(navigationController: self.navigationController!, data: data)
    }
}

extension ViewController: SearchCoordinatorDelegate {
    func userDidSelectCountry(model: CountryViewModel) {

    }
}
