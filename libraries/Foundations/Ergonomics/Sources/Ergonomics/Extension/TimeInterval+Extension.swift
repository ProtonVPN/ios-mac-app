//
//  Created on 2022-01-17.
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

public extension TimeInterval {
    static func milliseconds(_ milliseconds: Int) -> Self {
        Self(milliseconds) / 1000
    }

    static func minutes(_ minutes: Int) -> Self {
        Self(minutes) * 60
    }

    static func hours(_ hours: Int) -> Self {
        Self(hours) * .minutes(60)
    }

    static func days(_ days: Int) -> Self {
        Self(days) * .hours(24)
    }

    init(days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) {
        self.init(.days(days) + .hours(hours) + .minutes(minutes) + Double(seconds))
    }

    // swiftlint:disable large_tuple
    var components: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let days = Int(self) / (60 * 60 * 24)
        let hours = Int(self) / (60 * 60) % 24
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60

        return (days, hours, minutes, seconds)
    }
    // swiftlint:enable large_tuple

    var asColonSeparatedString: String {
        return self.asColonSeparatedString(maxUnit: .day, minUnit: .hour)
    }

    private func components(largestUnit: Self.Unit, smallestUnit: Self.Unit) -> [Int] {
        var totalSeconds: Int = Int(self)
        var previousUnit: Self.Unit?
        let components: [Int] = Unit.allCases
            .reduce(
                into: [],
                { result, unit in
                    if unit <= largestUnit {
                        var value = totalSeconds / unit.seconds
                        if let previousUnit {
                            value = value % previousUnit.seconds
                        }

                        if value > 0 || unit <= smallestUnit {
                            result.append(value)
                            totalSeconds -= value * unit.seconds
                            previousUnit = unit
                        }
                    }
                }
            )
        assert(totalSeconds == 0)
        return components
    }

    enum Unit: CaseIterable, Comparable {
        case day
        case hour
        case minute
        case second

        var seconds: Int {
            switch self {
            case .second: return 1
            case .minute: return 60
            case .hour: return 60 * 60
            case .day: return 60 * 60 * 24
            }
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.seconds < rhs.seconds
        }
    }


    func asColonSeparatedString(maxUnit: Self.Unit, minUnit: Self.Unit) -> String {
        components(largestUnit: maxUnit, smallestUnit: minUnit)
            .map { String(format: "%02i", $0) }
            .joined(separator: ":")
    }
}
