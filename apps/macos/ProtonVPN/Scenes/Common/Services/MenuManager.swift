//
//  Created on 02/09/2025 by Max Kupetskyi.
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

import Cocoa
import LegacyCommon
import Strings

final class MenuManager {
    private var protonVpnMenu: ProtonVPNMenuController = .init()
    private var profilesMenu: ProfilesMenuController = .init()
    private var helpMenu: HelpMenuController = .init()
    private var statusMenu: StatusMenuWindowController = .init(window: nil)
    private var editMenu: EditMenuController = .init()
    private var windowMenu: WindowMenuController = .init()

    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
    }

    func createMainMenu() {
        let mainMenu = NSMenu(title: "Main Menu")

        // Create ProtonVPN menu (Application menu)
        let protonVpnMenuItem = NSMenuItem(title: "ProtonVPN", action: nil, keyEquivalent: "")
        protonVpnMenuItem.submenu = protonVpnMenu.menu
        mainMenu.addItem(protonVpnMenuItem)

        // Create Edit menu
        let editMenuItem = NSMenuItem(title: Localizable.editMenuTitle, action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu.editMenu
        mainMenu.addItem(editMenuItem)

        // Create Profiles menu
        let profilesMenuItem = NSMenuItem(title: Localizable.profiles, action: nil, keyEquivalent: "")
        profilesMenuItem.submenu = profilesMenu.profilesMenu
        profilesMenu.profilesMenuItem = profilesMenuItem
        mainMenu.addItem(profilesMenuItem)

        // Create Window menu
        let windowMenuItem = NSMenuItem(title: Localizable.menuWindow, action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu.windowMenu
        mainMenu.addItem(windowMenuItem)

        // Create Help menu
        let helpMenuItem = NSMenuItem(title: Localizable.help, action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu.helpMenu
        mainMenu.addItem(helpMenuItem)

        // Set the main menu
        NSApp.mainMenu = mainMenu

        // Ensure the application menu (first menu) is properly set as the Apple menu
        // This is important for macOS to recognize it as the application menu
        NSApp.servicesMenu = NSMenu() // Initialize services menu
        NSApp.windowsMenu = windowMenu.windowMenu // Set the window menu
        NSApp.helpMenu = helpMenu.helpMenu // Set the help menu
    }

    func updateMenuControllers() {
        protonVpnMenu.update(with: container.makeProtonVpnMenuViewModel())
        profilesMenu.update(with: container.makeProfilesMenuViewModel())
        helpMenu.update(with: container.makeHelpMenuViewModel())
        statusMenu.update(with: container.makeStatusMenuWindowModel())
        container.makeWindowService().setStatusMenuWindowController(statusMenu)
    }
}
