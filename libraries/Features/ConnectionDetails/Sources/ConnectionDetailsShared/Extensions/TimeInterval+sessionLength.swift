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

import Dependencies
import Foundation
import Strings

public extension TimeInterval {
    internal static let secondsPerMinute = 60
    internal static let secondsPerHour = 60 * 60
    internal static let secondsPerDay = 60 * 60 * 24

    /// VPN session length text, localized by the system.
    /// Expects a non-positive interval (e.g. `sessionStart.timeIntervalSinceNow`).
    var sessionLengthText: String {
        @Dependency(\.locale) var locale
        return sessionLengthText(locale: locale)
    }

    func sessionLengthText(locale: Locale) -> String {
        let totalSeconds = max(0, Int(-self)) // truncation + positive-input clamp

        guard totalSeconds > 0 else {
            // .dropAll would suppress a lone zero unit, so format it explicitly.
            return Self.makeZeroLengthFormatter(locale: locale).string(from: DateComponents(second: 0)) ?? ""
        }

        var components = DateComponents()
        switch totalSeconds {
        case 0 ..< Self.secondsPerMinute:
            components.second = totalSeconds

        case Self.secondsPerMinute ..< Self.secondsPerHour:
            components.minute = totalSeconds / Self.secondsPerMinute
            components.second = totalSeconds % Self.secondsPerMinute

        case Self.secondsPerHour ..< Self.secondsPerDay:
            components.hour = totalSeconds / Self.secondsPerHour
            components.minute = (totalSeconds % Self.secondsPerHour) / Self.secondsPerMinute

        default:
            components.day = totalSeconds / Self.secondsPerDay
            components.hour = (totalSeconds % Self.secondsPerDay) / Self.secondsPerHour
        }

        return Self.makeSessionLengthFormatter(locale: locale).string(from: components) ?? ""
    }

    private static func makeSessionLengthFormatter(locale: Locale) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .short
        formatter.zeroFormattingBehavior = .dropAll
        formatter.calendar = Self.calendar(for: locale)
        return formatter
    }

    private static func makeZeroLengthFormatter(locale: Locale) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.second]
        formatter.unitsStyle = .short
        formatter.calendar = Self.calendar(for: locale)
        return formatter
    }

    private static func calendar(for locale: Locale) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar
    }
}
