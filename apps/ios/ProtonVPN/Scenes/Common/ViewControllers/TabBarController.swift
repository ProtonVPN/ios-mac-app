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

import UIKit
import LegacyCommon
import Strings

import ProtonCoreFeatureFlags

final class TabBarController: UITabBarController {

    private var quickConnectButtonConnecting = false
    private let quickConnectButton = UIButton()
    
    var viewModel: TabBarViewModel? {
        didSet {
            viewModel?.delegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        setupView()
        if !FeatureFlagsRepository.shared.isRedesigniOSEnabled {
            setupQuickConnectView()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        viewModel?.stateChanged()
    }

    func setupView() {
        view.backgroundColor = .backgroundColor()
        selectedIndex = 0
    }
    
    private func setupQuickConnectView() {
        quickConnectButton.backgroundColor = .clear
        quickConnectButton.layer.masksToBounds = true
        
        quickConnectButton.contentVerticalAlignment = .top
        quickConnectButton.contentHorizontalAlignment = .center
        quickConnectButton.imageView?.contentMode = .scaleAspectFit
        quickConnectButton.adjustsImageWhenHighlighted = false
        
        quickConnectButton.addTarget(self, action: #selector(quickConnectTapped), for: .touchUpInside)
        
        view.addSubview(quickConnectButton)
        
        let bottomItem: Any
        bottomItem = view.safeAreaLayoutGuide
        
        quickConnectButton.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = NSLayoutConstraint(item: quickConnectButton, attribute: .width, relatedBy: .equal, toItem: tabBar, attribute: .width, multiplier: 1 / CGFloat(tabBar.items?.count ?? 5), constant: 4)
        let heightConstraint = NSLayoutConstraint(item: quickConnectButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 66)
        let centerXConstraint = NSLayoutConstraint(item: quickConnectButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0)
        let bottomConstraint = NSLayoutConstraint(item: quickConnectButton, attribute: .bottom, relatedBy: .equal, toItem: bottomItem, attribute: .bottom, multiplier: 1, constant: 6)
        view.addConstraints([widthConstraint, heightConstraint, centerXConstraint, bottomConstraint])

        disconnectedQuickConnect()
    }
    
    @objc private func quickConnectTapped(_ sender: UIButton) {
        viewModel?.quickConnectTapped()
    }
}

extension TabBarController: TabBarViewModelDelegate {
    func connectedQuickConnect() {
        quickConnectButtonConnecting = false
        self.tabBar.items?[2].setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.weakTextColor()], for: .normal)
        self.tabBar.items?[2].title = Localizable.disconnect
        self.quickConnectButton.setImage(Asset.quickConnectActiveButton.image, for: .normal)
    }
    
    func connectingQuickConnect() {
        if !quickConnectButtonConnecting { // to avoid animation jumping, don't reset animation during multiple connecting stage calls
            self.tabBar.items?[2].setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.textAccent()], for: .normal)
            self.tabBar.items?[2].title = Localizable.connecting
            self.quickConnectButton.setImage(Asset.quickConnectConnectingButton.image, for: .normal)
        }
        
        quickConnectButtonConnecting = true
    }
    
    func disconnectedQuickConnect() {
        quickConnectButtonConnecting = false
        guard self.tabBar.items?.count > 2 else { return }
        self.tabBar.items?[2].setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.weakTextColor()], for: .normal)
        self.tabBar.items?[2].title = Localizable.quickConnect
        self.quickConnectButton.setImage(Asset.quickConnectInactiveButton.image, for: .normal)
    }
}

extension TabBarController: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // to help with data updating and easier to understand navigation, pop nvc to root
        if let navigationViewController = viewController as? UINavigationController, navigationViewController != self.selectedViewController {
            navigationViewController.popToRootViewController(animated: false)
        }
        
        if viewController is ProtonQCViewController {
            return false
        } else if let viewModel = viewModel, viewController == viewControllers?.last { // settings
            return viewModel.settingShouldBeSelected()
        } else {
            return true
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let viewModel, let navigationController = viewController as? UINavigationController,
           navigationController.visibleViewController is SettingsViewController {
            viewModel.settingsTabTapped()
        }
    }
}
