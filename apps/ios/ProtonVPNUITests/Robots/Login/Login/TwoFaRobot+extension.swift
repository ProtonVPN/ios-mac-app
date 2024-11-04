//
//  Created on 22/10/24.
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

import ProtonCoreTestingToolkitUITestsLogin
import UITestsHelpers
import fusion

private let authenticateButtonId = "TwoFactorViewController.authenticateButton"

public extension TwoFaRobot {
    func waitFor2FaDisappear<T: CoreElements>(robot _: T.Type) -> T {
        button(authenticateButtonId)
            .waitUntilGone(time: 15)
            .checkDoesNotExist(message: "2FA screen does not disappear in \(WaitTimeout.long) seconds")
        return T()
    }
}
