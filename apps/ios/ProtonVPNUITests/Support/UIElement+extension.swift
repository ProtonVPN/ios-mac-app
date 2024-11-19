//
//  Created on 19/11/24.
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

@testable import fusion
import XCTest

extension UIElement {

    /**
     Clears the text from the targeted UI element.
     Calls `clearText()` on the located UI element and returns the current instance of `UIElement`.
     */
    @discardableResult
    public func clearText() -> UIElement {
        uiElement()!.tapAndClearText()
        return self
    }
}
