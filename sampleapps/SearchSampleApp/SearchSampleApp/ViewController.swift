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
        coordinator?.start(navigationController: self.navigationController!)
    }
}

