//
//  FooterItemView.swift
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

class FooterItemView: NSView {

    @IBOutlet weak var createNewProfileButton: PrimaryActionButton!
    @IBOutlet weak var manageProfilesButton: InteractiveActionButton!
    
    private var viewModel: ProfilesSectionViewModel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        createNewProfileButton.title = Localizable.createNewProfile
        createNewProfileButton.target = self
        createNewProfileButton.action = #selector(createNewProfileButtonAction(_:))
        
        manageProfilesButton.title = Localizable.manageProfiles
        manageProfilesButton.target = self
        manageProfilesButton.action = #selector(manageProfilesButtonAction(_:))
    }
    
    func updateView(withModel viewModel: ProfilesSectionViewModel) {
        self.viewModel = viewModel
        manageProfilesButton.isHidden = !viewModel.canUseProfiles
    }
    
    @objc private func createNewProfileButtonAction(_ sender: NSButton) {
        viewModel.createNewProfileAction()
    }
    
    @objc private func manageProfilesButtonAction(_ sender: NSButton) {
        viewModel.manageProfilesAction()
    }
}
