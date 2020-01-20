//
//  ProfilesTabBarViewController.swift
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

enum ProfilesTab: Equatable {
    
    case overview
    case createNewProfile
}

class ProfilesTabBarViewController: NSViewController {

    @IBOutlet weak var headerLabel: NSTextField!
    @IBOutlet weak var backgroundView: ProfilesTabBarView!
    @IBOutlet weak var overviewButton: TabBarButton!
    @IBOutlet weak var createNewProfileButton: TabBarButton!
    
    let tabChanged = Notification.Name("ProfilesTabBarViewControllerTabChanged")
    
    private var tabChangedExternally: Notification.Name!
    private var activeTab: ProfilesTab?
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(tabChangedExternally: Notification.Name) {
        super.init(nibName: NSNib.Name("ProfilesTabBar"), bundle: nil)
        self.tabChangedExternally = tabChangedExternally
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupComponents()
        NotificationCenter.default.addObserver(self, selector: #selector(tabChanged(_:)),
                                               name: tabChangedExternally, object: nil)
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonDarkGrey().cgColor
    }
    
    private func setupComponents() {
        headerLabel.attributedStringValue = LocalizedString.profiles.attributed(withColor: .protonWhite(), fontSize: 36, alignment: .left)
        
        overviewButton.title = LocalizedString.overview
        overviewButton.target = self
        overviewButton.action = #selector(overviewButtonAction)
        
        createNewProfileButton.title = LocalizedString.createNewProfileHeader
        createNewProfileButton.target = self
        createNewProfileButton.action = #selector(createNewProfileButtonAction)
    }
    
    private func new(tab: ProfilesTab, externalSource: Bool = false) {
        activeTab = tab
        backgroundView.activeTab = activeTab
        overviewButton.isFocused = activeTab == .overview
        createNewProfileButton.isFocused = activeTab == .createNewProfile
        
        if !externalSource {
            NotificationCenter.default.post(name: tabChanged, object: activeTab!)
        }
    }
    
    @objc private func overviewButtonAction() {
        if activeTab != .overview {
            new(tab: .overview)
        }
    }
    
    @objc private func createNewProfileButtonAction() {
        if activeTab != .createNewProfile {
            new(tab: .createNewProfile)
        }
    }
    
    @objc private func tabChanged(_ notification: Notification) {
        if let tab = notification.object as? ProfilesTab {
            new(tab: tab, externalSource: true)
        }
    }
}
