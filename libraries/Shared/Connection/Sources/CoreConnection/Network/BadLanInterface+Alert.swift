//
//  Created on 29/05/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import Strings

public extension BadLanInterface {
    /// "misconfigured LAN" intercept alert
    func interceptAlert<Action>(
        enableKillSwitch: Action,
        connectAnyway: Action
    ) -> AlertState<Action> {
        AlertState {
            TextState(Localizable.badInterfaceIpRangeAlertTitle)
        } actions: {
            ButtonState(action: enableKillSwitch) {
                TextState(Localizable.killSwitchEnable)
            }
            ButtonState(role: .destructive, action: connectAnyway) {
                TextState(Localizable.continue)
            }
        } message: {
            TextState(Localizable.promptKillSwitchDueToBadInterfaceIpRange(
                name ?? "Unknown Interface",
                subnetDescription ?? "Unknown Subnet"
            ))
        }
    }
}
