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
    static func minutes(_ minutes: Int) -> Self {
        Self(minutes) * 60
    }

    static func hours(_ hours: Int) -> Self {
        Self(hours) * .minutes(60)
    }

    static func days(_ days: Int) -> Self {
        Self(days) * .hours(24)
    }

    var components: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let days = Int(self) / (60 * 60 * 24)
        let hours = Int(self) / (60 * 60) % 24
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60

        return (days, hours, minutes, seconds)
    }

    var asColonSeparatedString: String {
        let time = components
        if time.days > 0 {
            return String(format: "%02i:%02i:%02i:%02i",
                          time.days, time.hours, time.minutes, time.seconds)
        } else {
            return String(format: "%02i:%02i:%02i",
                          time.hours, time.minutes, time.seconds)
        }
    }
}
