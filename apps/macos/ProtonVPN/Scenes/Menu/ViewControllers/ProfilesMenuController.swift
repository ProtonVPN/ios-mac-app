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
import Ergonomics
import LegacyCommon
import Strings

final class ProfilesMenuController: NSObject {
    var profilesMenuItem: NSMenuItem?
    lazy var overviewItem: NSMenuItem = .init(title: Localizable.overview, action: #selector(overviewItemAction), keyEquivalent: "p").with {
        $0.isEnabled = false
        $0.target = self
    }

    lazy var createNewProfileItem: NSMenuItem = .init(title: Localizable.createNewProfile, action: #selector(createNewProfileItemAction), keyEquivalent: "P").with {
        $0.isEnabled = false
        $0.target = self
        $0.keyEquivalentModifierMask = .shift
    }

    lazy var profilesMenu: NSMenu = .init(title: Localizable.profiles).with {
        $0.autoenablesItems = false
        $0.items = [overviewItem, createNewProfileItem]
    }

    private var viewModel: ProfilesMenuViewModel!

    func update(with viewModel: ProfilesMenuViewModel) {
        self.viewModel = viewModel
        viewModel.contentChanged = { [weak self] in self?.setupEphemeralView() }
        viewModel.contentChanged?()
    }

    // MARK: - Private functions

    @objc
    private func overviewItemAction() {
        viewModel.overviewAction()
    }

    @objc
    private func createNewProfileItemAction() {
        viewModel.createNewProfileAction()
    }

    private func setupEphemeralView() {
        profilesMenuItem?.isHidden = !viewModel.areProfilesEnabled
        overviewItem.isEnabled = viewModel.areProfilesEnabled
        createNewProfileItem.isEnabled = viewModel.areProfilesEnabled
    }
}
