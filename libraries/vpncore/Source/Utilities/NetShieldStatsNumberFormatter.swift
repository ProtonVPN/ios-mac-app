//
//  Created on 28/03/2023.
//
//  Copyright (c) 2023 Proton AG
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

class NetShieldStatsNumberFormatter: NumberFormatter {

    override init() {
        super.init()
        allowsFloats = true
        maximumFractionDigits = 1
        maximumIntegerDigits = 3
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    let suffixes = ["", " K", " M", " G", " T", " P", " E"]

    public func string(from number: Int) -> String {
        var reduced = CGFloat(abs(number))
        var multiplier = 0
        while reduced >= 1_000 {
            reduced /= 1_000
            multiplier += 1
        }
        multiplier = min(multiplier, suffixes.count - 1)
        let multiplierString = suffixes[multiplier]
        let reducedNumber = NSNumber(value: reduced)
        return (string(from: reducedNumber) ?? "0") + multiplierString
    }
}
