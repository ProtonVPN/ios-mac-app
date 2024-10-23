//
//  Created on 23/10/2024.
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

public extension Int {
    var isPaidTier: Bool {
        !isFreeTier
    }
    var isFreeTier: Bool {
        self == Int.freeTier
    }
    static var freeTier: Int = .freeTier
    static var paidTier: Int = VpnTiers.plus
    static var internalTier: Int = VpnTiers.internal // Dev-only

    fileprivate struct VpnTiers {
        static let free = 0
        // 1 was historically used for basic plans, which no longer exist
        static let plus = 2 // also visionary
        static let `internal` = 3
    }
}
