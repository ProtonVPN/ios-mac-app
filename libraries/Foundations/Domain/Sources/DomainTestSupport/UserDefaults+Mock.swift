//
//  Created on 24.03.2025 by John Biggs.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation

public final class TestDefaults: UserDefaults, @unchecked Sendable {
    let suiteName: String

    public override init?(suiteName: String?) {
        guard let suiteName else { return nil }

        self.suiteName = suiteName

        super.init(suiteName: suiteName)

        // Clear for testing
        removePersistentDomain(forName: suiteName)
    }

    deinit {
        removePersistentDomain(forName: suiteName)
    }
}

public extension UserDefaults {
    static func testValue(suiteName: String = "\(#file)_line\(#line)") -> UserDefaults {
        guard let value = TestDefaults(suiteName: suiteName) else {
            fatalError("Could not initialize UserDefaults for \(suiteName)")
        }
        return value
    }
}
