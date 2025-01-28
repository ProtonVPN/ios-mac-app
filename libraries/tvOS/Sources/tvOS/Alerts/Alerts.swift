//
//  Created on 28/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Ergonomics
import ComposableArchitecture
import Strings

// MARK: - Error alerts definitions

let RefreshTokenExpiredAlert = AlertService.Alert(message: Localizable.invalidRefreshTokenPleaseLogin)
let ConnectionFailedAlert = AlertService.Alert(message: Localizable.connectionFailed)

// MARK: - Helpers

extension AlertService.Alert {
    func alertState<Action>(from: Action.Type) -> AlertState<Action> {
        let title = TextState(String(localized: title))
        let message = TextState(String(localized: message))
        return AlertState<Action>(title: title, message: message)
    }
}
