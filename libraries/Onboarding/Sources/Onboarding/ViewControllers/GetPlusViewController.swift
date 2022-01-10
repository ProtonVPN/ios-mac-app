//
//  Created on 10.01.2022.
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
import UIKit

final class GetPlusViewController: UIViewController {
    var planPurchaseViewController: UIViewController? {
        didSet {
            guard isViewLoaded else {
                return
            }

            setupPlanPurchaseViewController()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupPlanPurchaseViewController()
    }

    private func setupUI() {
        view.backgroundColor = .red
    }

    private func setupPlanPurchaseViewController() {
        guard let planPurchaseViewController = planPurchaseViewController else {
            return
        }

        addChild(planPurchaseViewController)
        view.addSubview(planPurchaseViewController.view)
        planPurchaseViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            planPurchaseViewController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            planPurchaseViewController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            planPurchaseViewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 16),
            planPurchaseViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
        ])
        planPurchaseViewController.didMove(toParent: self)
    }
}
