//
//  Created on 2023-06-08.
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

extension TimeInterval {

    /// VPN session length text (with translation)
    public var sessionLengthText: String {
        let time = -self

        switch time {
        case 0 ..< Self.minute:
            return Localizable.sessionLengthSeconds(Int(time))

        case Self.minute ..< Self.hour:
            let minutes = Int(time / Self.minute)
            let seconds = Int(time - Double(minutes) * Self.minute)
            return seconds > 0
            ? Localizable.sessionLengthMinutesAndSeconds(Int(minutes), Int(seconds))
            : Localizable.sessionLengthMinutes(Int(minutes))

        case Self.hour ..< Self.day:
            let hours = Int(time / (Self.hour))
            let minutes = Int((time - Double(hours) * Self.hour) / Self.minute)
            return minutes > 0
            ? Localizable.sessionLengthHoursAndMinutes(Int(hours), Int(minutes))
            : Localizable.sessionLengthHours(Int(hours))

        case Self.day...:
            let days = Int(time / (Self.day))
            let hours = Int((time - Double(days) * Self.day) / Self.hour)
            return hours > 0
            ? Localizable.sessionLengthDaysAndHours(Int(days), Int(hours))
            : Localizable.sessionLengthDays(Int(days))

        default:
            return ""
        }
    }

    static var minute: Self = 60
    static var hour: Self = 60 * 60
    static var day: Self = 60 * 60 * 24

}
