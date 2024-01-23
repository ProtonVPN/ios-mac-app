//
//  Created on 22/01/2024.
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

import Foundation

public extension CGPoint {
    enum CoordinateSpace {
        public static let topLeft = CGPoint(x: 0, y: 0)
        public static let top = CGPoint(x: 0.5, y: 0)
        public static let topRight = CGPoint(x: 1, y: 0)
        public static let right = CGPoint(x: 0, y: 0.5)
        public static let bottomRight = CGPoint(x: 1, y: 1)
        public static let bottom = CGPoint(x: 0.5, y: 1)
        public static let bottomLeft = CGPoint(x: 0, y: 1)
        public static let left = CGPoint(x: 1, y: 0.5)
    }
}
