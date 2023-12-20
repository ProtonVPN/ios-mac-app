//
//  Created on 2022-01-13.
//
//  Copyright (c) 2022 Proton AG
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

import fusion
import ProtonCoreTestingToolkitUITestsLogin

private let phoneTextFieldId = "RecoveryViewController.recoveryPhoneTextField.textField"
private let nextButtonId = "RecoveryViewController.nextButton"

class RecoveryRobot: CoreElements {
    
    let coreRecoveryRobot = ProtonCoreTestingToolkitUITestsLogin.RecoveryRobot()
    
    func nextButtonTap<T: CoreElements>(robot _: T.Type) -> T {
        button(nextButtonId).tap()
        return T()
    }

    func insertRecoveryEmail(_ email: String) -> RecoveryRobot {
        _ = self.coreRecoveryRobot
            .self.insertRecoveryEmail(email: email)
        return RecoveryRobot()
    }
    
    private func insertRecoveryNumber(_ number: String) -> RecoveryRobot {
        textField(phoneTextFieldId).tap().typeText(number)
        return self
    }
}
