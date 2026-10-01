//
//  Created on 01/10/2026 by Max Kupetskyi.
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

import Domain
import Testing

@Suite("Bundle location")
struct BundleLocationTests {
    @Test(
        "The location comes from the shape of the bundle path",
        arguments: [
            ("/Applications/ProtonVPN.app", BundleLocation.applications),
            ("/Applications/VPN/ProtonVPN.app", .applications),
            ("/Users/someone/Downloads/ProtonVPN.app", .downloads),
            ("/Volumes/ProtonVPN/ProtonVPN.app", .dmgVolume),
            ("/private/var/folders/ab/xyz/T/AppTranslocation/1234/d/ProtonVPN.app", .translocated),
            ("/Users/someone/Applications/ProtonVPN.app", .other),
            ("/Users/someone/Desktop/ProtonVPN.app", .other),
        ]
    )
    func location(bundlePath: String, expected: BundleLocation) {
        #expect(BundleLocation(bundlePath: bundlePath) == expected)
    }
}
