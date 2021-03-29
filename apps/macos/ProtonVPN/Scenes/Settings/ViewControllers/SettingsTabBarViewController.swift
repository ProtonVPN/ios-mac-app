//
//  SettingsTabBarViewController.swift
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

class SettingsTabBarViewController: NSViewController {
    
    @IBOutlet weak var headerLabel: NSTextField!
    @IBOutlet weak var tabBarView: TabBarView!
    @IBOutlet weak var generalButton: TabBarButton!
    @IBOutlet weak var connectionButton: TabBarButton!
    @IBOutlet weak var accountButton: TabBarButton!
    
    private var viewModel: SettingsTabBarViewModel!
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: SettingsTabBarViewModel) {
        super.init(nibName: NSNib.Name("SettingsTabBar"), bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        setupView()
        setupComponents()
        NotificationCenter.default.addObserver(self, selector: #selector(tabChanged(_:)),
                                               name: viewModel.tabChanged, object: nil)
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonDarkGrey().cgColor
        
        tabBarView.tabWidth = accountButton.bounds.width
        tabBarView.tabHeight = accountButton.bounds.height
        tabBarView.tabCount = 3
        tabBarView.focusedTabIndex = viewModel.activeTab.rawValue
    }
    
    private func setupComponents() {
        headerLabel.attributedStringValue = LocalizedString.preferences.attributed(withColor: .protonWhite(), fontSize: 36, alignment: .left)
        
        generalButton.title = LocalizedString.general
        generalButton.target = self
        generalButton.action = #selector(generalButtonAction)
        generalButton.isFocused = viewModel.activeTab == .general
        
        connectionButton.title = LocalizedString.connection
        connectionButton.target = self
        connectionButton.action = #selector(connectionButtonAction)
        connectionButton.isFocused = viewModel.activeTab == .connection
        
        accountButton.title = LocalizedString.account
        accountButton.target = self
        accountButton.action = #selector(accountButtonAction)
        accountButton.isFocused = viewModel.activeTab == .account
    }
    
    @objc private func generalButtonAction() {
        viewModel.generalAction()
    }
    
    @objc private func connectionButtonAction() {
        viewModel.connectionAction()
    }
        
    @objc private func accountButtonAction() {
        viewModel.accountAction()
    }
    
    @objc private func tabChanged(_ notification: Notification) {
        if let tab = notification.object as? SettingsTab {
            tabBarView.focusedTabIndex = tab.rawValue
            generalButton.isFocused = tab == .general
            connectionButton.isFocused = tab == .connection
            accountButton.isFocused = tab == .account
        }
    }
}
