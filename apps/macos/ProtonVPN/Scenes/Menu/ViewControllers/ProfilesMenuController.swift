//
//  ProfilesMenuController.swift
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
import LegacyCommon
import Strings

class ProfilesMenuController: NSObject {
    @IBOutlet weak var profilesMenuItem: NSMenuItem!
    @IBOutlet weak var profilesMenu: NSMenu!
    @IBOutlet weak var overviewItem: NSMenuItem!
    @IBOutlet weak var createNewProfileItem: NSMenuItem!
    
    private var viewModel: ProfilesMenuViewModel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        setupPersistentView()
    }
    
    func update(with viewModel: ProfilesMenuViewModel) {
        self.viewModel = viewModel
        viewModel.contentChanged = { [weak self] in self?.setupEphemeralView() }
        viewModel.contentChanged?()
    }
    
    // MARK: - Private functions
    private func setupPersistentView() {
        profilesMenu.title = Localizable.profiles
        profilesMenu.autoenablesItems = false
        
        overviewItem.title = Localizable.overview
        overviewItem.isEnabled = false
        overviewItem.target = self
        overviewItem.action = #selector(overviewItemAction)
        
        createNewProfileItem.title = Localizable.createNewProfile
        createNewProfileItem.isEnabled = false
        createNewProfileItem.target = self
        createNewProfileItem.action = #selector(createNewProfileItemAction)
    }
    
    @objc private func overviewItemAction() {
        viewModel.overviewAction()
    }
    
    @objc private func createNewProfileItemAction() {
        viewModel.createNewProfileAction()
    }

    private func setupEphemeralView() {
        profilesMenuItem.isHidden = !viewModel.areProfilesEnabled
    }
}
