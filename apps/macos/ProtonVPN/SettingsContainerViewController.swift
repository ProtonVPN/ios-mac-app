//
//  SettingsContainerViewController.swift
//  ProtonVPN - Created on 27.06.19.
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

import Cocoa
import vpncore

class SettingsContainerViewController: NSViewController {

    typealias Factory = PropertiesManagerFactory & CoreAlertServiceFactory & AppStateManagerFactory & VpnGatewayFactory
    
    @IBOutlet weak var tabBarControllerViewContainer: NSView!
    @IBOutlet weak var activeControllerViewContainer: NSView!
    
    private let factory: Factory
    private let viewModel: SettingsContainerViewModel
    private var tabBarViewController: SettingsTabBarViewController!
    private var tabBarViewModel: SettingsTabBarViewModel
    private var activeViewController: NSViewController?
    
    lazy var generalViewController: GeneralSettingsViewController = { [unowned self] in
        let viewModel = GeneralViewModel(factory: self.factory)
        let vc = GeneralSettingsViewController(viewModel: viewModel)
        viewModel.setViewController(vc)
        return vc
    }()
    
    lazy var connectionViewController: ConnectionSettingsViewController = {
        let viewModel = ConnectionSettingsViewModel(vpnGateway: self.viewModel.vpnGateway, firewallManager: self.viewModel.firewallManager)
        return ConnectionSettingsViewController(viewModel: viewModel)
    }()
    
    lazy var accountViewController: AccountViewController = {
        return AccountViewController()
    }()
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: SettingsContainerViewModel, tabBarViewModel: SettingsTabBarViewModel, factory: Factory) {
        self.viewModel = viewModel
        self.tabBarViewModel = tabBarViewModel
        self.factory = factory
        super.init(nibName: NSNib.Name("SettingsContainer"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTabBar()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        tabBarViewModel.activeTab = tabBarViewModel.activeTab
    }
    
    private func setupTabBar() {
        NotificationCenter.default.addObserver(self, selector: #selector(tabChanged(_:)),
                                               name: tabBarViewModel.tabChanged, object: nil)
        tabBarViewController = SettingsTabBarViewController(viewModel: tabBarViewModel)
        tabBarControllerViewContainer.pin(viewController: tabBarViewController)
    }
    
    private func set(viewController: NSViewController) {
        if let activeViewController = activeViewController {
            activeControllerViewContainer.willRemoveSubview(activeViewController.view)
            activeViewController.view.removeFromSuperview()
            activeViewController.removeFromParent()
        }
        activeControllerViewContainer.pin(viewController: viewController)
        activeViewController = viewController
    }
    
    @objc private func tabChanged(_ notification: Notification) {
        if let tab = notification.object as? SettingsTab {
            switch tab {
            case .general:
                set(viewController: generalViewController)
            case .connection:
                set(viewController: connectionViewController)
            case .account:
                set(viewController: accountViewController)
            }
        }
    }
}
