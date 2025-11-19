//
//  TabBarController.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import LegacyCommon
import Strings
import UIKit

import ProtonCoreFeatureFlags

final class TabBarController: UITabBarController {
    var viewModel: TabBarViewModel

    init(viewModel: TabBarViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        traitOverrides.horizontalSizeClass = .compact
        setupView()
    }

    func setupView() {
        view.backgroundColor = .backgroundColor()
        selectedIndex = 0
    }
}

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // to help with data updating and easier to understand navigation, pop nvc to root
        if let navigationViewController = viewController as? UINavigationController, navigationViewController != selectedViewController {
            navigationViewController.popToRootViewController(animated: false)
        }

        if viewController == viewControllers?.last { // settings
            return viewModel.settingShouldBeSelected()
        }
        return true
    }

    func tabBarController(_: UITabBarController, didSelect viewController: UIViewController) {
        if let navigationController = viewController as? UINavigationController,
           navigationController.visibleViewController is SettingsViewController {
            viewModel.settingsTabTapped()
        }
    }
}
