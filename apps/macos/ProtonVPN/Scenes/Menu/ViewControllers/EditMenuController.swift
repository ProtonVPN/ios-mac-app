//
//  Created on 2025-05-22 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import AppKit
import Strings

class EditMenuController: NSObject {
    @IBOutlet var editMenu: NSMenu!
    @IBOutlet var cutItem: NSMenuItem!
    @IBOutlet var copyItem: NSMenuItem!
    @IBOutlet var pasteItem: NSMenuItem!
    @IBOutlet var deleteItem: NSMenuItem!
    @IBOutlet var selectAllItem: NSMenuItem!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupPersistentView()
    }

    // MARK: - Private functions

    private func setupPersistentView() {
        editMenu.title = Localizable.editMenuTitle
        cutItem.title = Localizable.cutMenuTitle
        copyItem.title = Localizable.copyMenuTitle
        pasteItem.title = Localizable.pasteMenuTitle
        deleteItem.title = Localizable.deleteMenuTitle
        selectAllItem.title = Localizable.selectAllMenuTitle
    }
}
