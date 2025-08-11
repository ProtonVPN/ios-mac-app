//
//  Created on 06/08/2025 by Max Kupetskyi.
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
import LegacyCommon

// MARK: - Factory Class

enum QuickSettingFactory {
    static func createConfiguration(
        type: QuickSettingType,
        presenter: QuickSettingDropdownPresenterProtocol,
        button: QuickSettingButton,
        container: NSBox
    ) -> QuickSettingConfiguration {
        switch type {
        case .netShieldDisplay:
            NetShieldQuickSettingConfiguration(
                presenter: presenter,
                button: button,
                container: container
            )
        case .portForwardingDisplay:
            PortForwardingQuickSettingConfiguration(
                presenter: presenter,
                button: button,
                container: container
            )
        case .secureCoreDisplay, .killSwitchDisplay:
            GenericQuickSettingConfiguration(
                type: type,
                presenter: presenter,
                button: button,
                container: container
            )
        }
    }
}
