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

protocol GetPlusViewControllerDelegate: AnyObject {
    func userDidRequestBackFromGetPlus()
}

final class GetPlusViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var titleLabel: UILabel!

    // MARK: Properties

    var planPurchaseViewController: UIViewController? {
        didSet {
            guard isViewLoaded else {
                return
            }

            setupPlanPurchaseViewController()
        }
    }

    weak var delegate: GetPlusViewControllerDelegate?

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupPlanPurchaseViewController()
    }

    private func setupUI() {
        baseViewStyle(view)
        pageTitleStyle(titleLabel)

        titleLabel.text = LocalizedString.onboardingGetPlus

        let backButton = UIBarButtonItem(image: UIImage(named: "BackButton", in: Bundle.module, compatibleWith: nil), style: .plain, target: self, action: #selector(backTapped))
        backButton.accessibilityLabel = "BackButton"
        navigationItem.leftBarButtonItem = backButton
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
            planPurchaseViewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            planPurchaseViewController.view.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
        ])
        planPurchaseViewController.didMove(toParent: self)
    }

    // MARK: Actions

    @objc private func backTapped() {
        delegate?.userDidRequestBackFromGetPlus()
    }
}
