//
//  Created on 17/05/2023.
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
import Strings

public class NetShieldStatsNumberFormatter: NumberFormatter {

    public override init() {
        super.init()
        allowsFloats = true
        maximumFractionDigits = 1
        maximumIntegerDigits = 3
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum Suffix: Int {
        case kilo = 1
        case mega = 2
        case giga = 3
        case tera = 4
        case peta = 5
        case exa = 6

        func localized(amount: String) -> String {
            switch self {
            case .kilo:
                return Localizable.netshieldStatsBlockedK(amount)
            case .mega:
                return Localizable.netshieldStatsBlockedM(amount)
            case .giga:
                return Localizable.netshieldStatsBlockedG(amount)
            case .tera:
                return Localizable.netshieldStatsBlockedT(amount)
            case .peta:
                return Localizable.netshieldStatsBlockedP(amount)
            case .exa:
                return Localizable.netshieldStatsBlockedE(amount)
            }
        }
    }

    public func string(from number: Int) -> String {
        var reduced = CGFloat(abs(number))
        var multiplier = 0
        while reduced >= 1_000 {
            reduced /= 1_000
            multiplier += 1
        }
        let suffix = Suffix(rawValue: multiplier)
        let amount = string(from: NSNumber(value: reduced)) ?? "0"
        return suffix?.localized(amount: amount) ?? "\(amount)"
    }
}
