//
//  Created on 20/07/2026.
//
//  Copyright (c) 2026 Proton AG
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

import CustomDump
import Triangulation

// Failure-message representations for the geometry types tests assert on. Test-support-only: the
// production modules stay free of dump dependencies (Triangulation deliberately depends on nothing).

extension Angle: CustomDumpStringConvertible {
    /// `Angle` is radian-backed, but every threshold in the map domain is authored in degrees
    /// (`.degrees(1.5)` and friends), so a diff in degrees is the one a human can check by eye.
    public var customDumpDescription: String {
        "\(degrees)°"
    }
}
