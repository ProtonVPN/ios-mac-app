//
//  Created on 4/10/24.
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
    
    @discardableResult
    public func checkExists(message: @autoclosure () -> String, file: StaticString = #filePath, line: UInt = #line) -> UIElement {
        XCTAssertTrue(
            uiElement()!.exists,
            message(),
            file: file,
            line: line
        )
        return self
    }
    
    @discardableResult
    public func checkContainsValue(_ value: String, file: StaticString = #filePath, line: UInt = #line) -> UIElement {
        guard let stringValue = uiElement()!.value as? String else {
            XCTFail("Element doesn't have text value.")
            return self
        }
        XCTAssertTrue(
            stringValue.contains(value),
            "Expected Element text value to contain: \"\(value)\", but found: \"\(stringValue)\"",
            file: file,
            line: line
        )
        return self
    }
}
