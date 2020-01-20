//
//  SidebarTabBarViewController.swift
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

enum SidebarTab {
    case countries
    case profiles
}

class SidebarTabBarViewController: NSViewController {
    
    let tabChanged = Notification.Name("SidebarTabBarViewControllerTabChanged")
    
    @IBOutlet weak var tabBarView: SidebarTabBarView!
    @IBOutlet weak var countriesButton: TabBarButton!
    @IBOutlet weak var profilesButton: TabBarButton!
    
    var activeTab: SidebarTab? {
        didSet {
            new(tab: activeTab!)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required init() {
        super.init(nibName: NSNib.Name("SidebarTabBar"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        setupButtons()
    }
    
    private func setupButtons() {
        countriesButton.title = LocalizedString.countries
        countriesButton.target = self
        countriesButton.action = #selector(countriesTabAction(_:))
        
        profilesButton.title = LocalizedString.profiles
        profilesButton.target = self
        profilesButton.action = #selector(profilesTabAction(_:))
    }
    
    private func new(tab: SidebarTab) {
        tabBarView.activeTab = tab
        countriesButton.isFocused = tab == .countries
        profilesButton.isFocused = tab == .profiles
        NotificationCenter.default.post(name: tabChanged, object: activeTab!)
    }
    
    @objc private func countriesTabAction(_ sender: NSButton) {
        if activeTab != .countries {
            activeTab = .countries        }
    }

    @objc private func profilesTabAction(_ sender: NSButton) {
        if activeTab != .profiles {
            activeTab = .profiles
        }
    }
}
