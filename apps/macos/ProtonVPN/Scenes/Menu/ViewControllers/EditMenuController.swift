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
import Ergonomics
import Strings

final class EditMenuController: NSObject {
    var undoItem: NSMenuItem = .init(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z").with {
        $0.target = nil // nil target uses the responder chain
    }

    var redoItem: NSMenuItem = .init(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z").with {
        $0.target = nil
    }

    var cutItem: NSMenuItem = .init(title: Localizable.cutMenuTitle, action: #selector(NSText.cut(_:)), keyEquivalent: "x").with {
        $0.target = nil
    }

    var copyItem: NSMenuItem = .init(title: Localizable.copyMenuTitle, action: #selector(NSText.copy(_:)), keyEquivalent: "c").with {
        $0.target = nil
    }

    var pasteItem: NSMenuItem = .init(title: Localizable.pasteMenuTitle, action: #selector(NSText.paste(_:)), keyEquivalent: "v").with {
        $0.target = nil
    }

    var deleteItem: NSMenuItem = .init(title: Localizable.deleteMenuTitle, action: #selector(NSText.delete(_:)), keyEquivalent: "").with {
        $0.target = nil
    }

    var selectAllItem: NSMenuItem = .init(title: Localizable.selectAllMenuTitle, action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a").with {
        $0.target = nil
    }

    lazy var editMenu: NSMenu = .init(title: Localizable.editMenuTitle).with {
        $0.items = [undoItem, redoItem, NSMenuItem.separator(), cutItem, copyItem, pasteItem, deleteItem, selectAllItem]
    }
}
