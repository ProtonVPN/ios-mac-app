//
//  ProtonVpnMenuController.swift
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

class ProtonVpnMenuController: NSObject {
    
    @IBOutlet weak var aboutItem: NSMenuItem!
    @IBOutlet weak var checkForUpdatesItem: NSMenuItem!
    @IBOutlet weak var preferencesItem: NSMenuItem!
    @IBOutlet weak var logOutItem: NSMenuItem!
    @IBOutlet weak var showAllItem: NSMenuItem!
    @IBOutlet weak var quitItem: NSMenuItem!
    
    private var viewModel: ProtonVpnMenuViewModel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupPersistentView()
    }
    
    func update(with viewModel: ProtonVpnMenuViewModel) {
        self.viewModel = viewModel
        viewModel.contentChanged = { [unowned self] in self.setupEphemeralView() }
    }
    
    // MARK: - Private functions
    private func setupPersistentView() {
        aboutItem.isEnabled = true
        aboutItem.target = self
        aboutItem.action = #selector(aboutItemAction)
        
        checkForUpdatesItem.isEnabled = true
        checkForUpdatesItem.target = self
        checkForUpdatesItem.action = #selector(checkForUpdatesAction)
        
        preferencesItem.isEnabled = false
        preferencesItem.target = self
        preferencesItem.action = #selector(preferencesItemAction)
        
        logOutItem.isEnabled = false
        logOutItem.target = self
        logOutItem.action = #selector(logOutItemAction)
        
        showAllItem.isEnabled = true
        showAllItem.target = self
        showAllItem.action = #selector(showAllItemAction)
        
        quitItem.isEnabled = true
        quitItem.target = self
        quitItem.action = #selector(quitItemAction)
    }
    
    private func setupEphemeralView() {
        preferencesItem.isEnabled = viewModel.isPreferencesEnabled
        logOutItem.isEnabled = viewModel.isLogOutEnabled
    }
    
    @objc private func aboutItemAction() {
        viewModel.openAboutAction()
    }
    
    @objc private func checkForUpdatesAction() {
        viewModel.checkForUpdatesAction()
    }
    
    @objc private func preferencesItemAction() {
        viewModel.openPreferencesAction()
    }
    
    @objc private func logOutItemAction() {
        viewModel.logOutAction()
    }
    
    @objc private func showAllItemAction() {
        viewModel.showAllAction()
    }
    
    @objc private func quitItemAction() {
        viewModel.quitAction()
    }
}
