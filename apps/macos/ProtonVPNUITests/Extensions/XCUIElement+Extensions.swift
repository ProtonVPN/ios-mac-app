//
//  Created on 03/03/2022.
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

import Foundation
import XCTest

extension XCUIElement {
    /// Forcibly clicks the element if its not hittable.
    ///
    /// - Parameters:
    ///   - dx: The x-coordinate normalized offset. Default value is 0.5.
    ///   - dy: The y-coordinate normalized offset. Default value is 0.5.
    func forceClick(dx: Double = 0.5, dy: Double = 0.5) {
        if isHittable {
            click()
        } else {
            coordinatesClick(dx: dx, dy: dy)
        }
    }
    
    /// Clicks at a given coordinate.
    ///
    /// - Parameters:
    ///   - dx: The x-coordinate normalized offset. Default value is 0.5.
    ///   - dy: The y-coordinate normalized offset. Default value is 0.5.
    func coordinatesClick(dx: Double = 0.5, dy: Double = 0.5) {
        let coordinate: XCUICoordinate = self.coordinate(withNormalizedOffset: CGVector.init(dx: dx, dy: dy))
        coordinate.click()
    }
    
    /// Forcibly hovers the element if its not hittable.
    ///
    /// - Parameters:
    ///   - dx: The x-coordinate normalized offset. Default value is 0.5.
    ///   - dy: The y-coordinate normalized offset. Default value is 0.5.
    func forceHover(dx: Double = 0.5, dy: Double = 0.5) {
        if isHittable {
            hover()
        } else {
            coordinatesHover(dx: dx, dy: dy)
        }
    }
    
    /// Hovers over a given coordinate.
    ///
    /// - Parameters:
    ///   - dx: The x-coordinate normalized offset. Default value is 0.5.
    ///   - dy: The y-coordinate normalized offset. Default value is 0.5.
    func coordinatesHover(dx: Double = 0.5, dy: Double = 0.5) {
        let coordinate: XCUICoordinate = self.coordinate(withNormalizedOffset: CGVector.init(dx: dx, dy: dy))
        coordinate.hover()
    }
}
