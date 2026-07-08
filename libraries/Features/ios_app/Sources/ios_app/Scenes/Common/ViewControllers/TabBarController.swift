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
import ProtonCoreFeatureFlags
import Strings
import UIKit

final class TabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        traitOverrides.horizontalSizeClass = .compact
        setupView()
    }

    func setupView() {
        if #available(iOS 26.0, *) {
            // Remove the opaque background color so the Liquid Glass tab bar
            // can blur and reflect content behind it naturally.
            view.backgroundColor = .clear
            tabBar.scrollEdgeAppearance = nil
            // Remove any custom tab bar appearance overrides so the system
            // can render the Liquid Glass material automatically.
            tabBar.standardAppearance = UITabBarAppearance()
        } else {
            view.backgroundColor = .backgroundColor()
        }

        selectedIndex = 0
    }
}
