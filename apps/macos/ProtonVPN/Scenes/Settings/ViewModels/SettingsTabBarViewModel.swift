//
//  SettingsTabBarViewModel.swift
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

import Foundation

enum SettingsTab: Int {
    case general
    case connection
    case account
}

class SettingsTabBarViewModel {
    
    let tabChanged = Notification.Name("SettingsTabBarViewModelTabChanged") // two observers
    
    var activeTab: SettingsTab {
        didSet {
            NotificationCenter.default.post(name: tabChanged, object: activeTab)
        }
    }
    
    init(initialTab: SettingsTab) {
        activeTab = initialTab
    }
    
    func generalAction() {
        if activeTab != .general {
            activeTab = .general
        }
    }
    
    func connectionAction() {
        if activeTab != .connection {
            activeTab = .connection
        }
    }
    
    func accountAction() {
        if activeTab != .account {
            activeTab = .account
        }
    }
}
