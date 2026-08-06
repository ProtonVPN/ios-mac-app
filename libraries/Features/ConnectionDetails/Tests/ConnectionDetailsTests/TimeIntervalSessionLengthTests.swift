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

@testable import ConnectionDetailsShared
import Dependencies
import Foundation
import Testing

@Suite("TimeInterval.sessionLengthText")
struct SessionLengthTextTests {
    private static let minute = TimeInterval(TimeInterval.secondsPerMinute)
    private static let hour = TimeInterval(TimeInterval.secondsPerHour)
    private static let day = TimeInterval(TimeInterval.secondsPerDay)

    // MARK: Test data (explicitly typed — keeps the type checker fast)

    private static let secondsCases: [(TimeInterval, String)] = [
        (-1, "1 sec"),
        (-59, "59 sec"),
    ]

    private static let minutesCases: [(TimeInterval, String)] = [
        (-minute, "1 min"),
        (-(minute + 1), "1 min, 1 sec"),
        (-(minute + 59), "1 min, 59 sec"),
        (-(2 * minute + 5), "2 min, 5 sec"),
        (-(hour - 1), "59 min, 59 sec"),
    ]

    private static let hoursCases: [(TimeInterval, String)] = [
        (-hour, "1 hr"),
        (-(hour + minute), "1 hr, 1 min"),
        (-(hour + 59 * minute), "1 hr, 59 min"),
        (-(2 * hour), "2 hr"),
        (-(day - minute), "23 hr, 59 min"),
    ]

    private static let daysCases: [(TimeInterval, String)] = [
        (-day, "1 day"),
        (-(day + hour), "1 day, 1 hr"),
        (-(day + 23 * hour), "1 day, 23 hr"),
        (-(2 * day), "2 days"),
        (-(381 * day + 16 * hour), "381 days, 16 hr"),
    ]

    private static let truncationCases: [(TimeInterval, String)] = [
        (-(hour + 59 * minute + 50), "1 hr, 59 min"), // 50 sec dropped, must NOT round to "2 hr"
        (-(hour + 59 * minute + 25), "1 hr, 59 min"),
        (-(day + 23 * hour + 55), "1 day, 23 hr"), // 55 sec dropped, no promotion to minutes
        (-(day - 0.001), "23 hr, 59 min"), // 1 ms short of a day stays in hours bucket
    ]

    private static let boundaryCases: [(TimeInterval, String)] = [
        (-(minute - 1), "59 sec"),
        (-minute, "1 min"),
        (-(hour - 1), "59 min, 59 sec"),
        (-hour, "1 hr"),
        (-(day - minute), "23 hr, 59 min"),
        (-day, "1 day"),
    ]

    private static let fractionalCases: [(TimeInterval, String)] = [
        (-(minute - 0.1), "59 sec"), // stays in seconds bucket, not "1 min"
        (-(minute + 0.5), "1 min"),
        (-(hour + 0.9), "1 hr"),
    ]

    private static let zeroCases: [TimeInterval] = [-0.0, -0.4, -0.999]
    private static let positiveCases: [TimeInterval] = [1, minute, day]

    // MARK: Helper

    /// Pins the locale dependency so assertions don't depend on the test host's settings.
    private func text(_ interval: TimeInterval) -> String {
        withDependencies {
            $0.locale = Locale(identifier: "en_US")
        } operation: {
            interval.sessionLengthText
        }
    }

    // MARK: Tests

    @Test("seconds bucket", arguments: secondsCases)
    func seconds(interval: TimeInterval, expected: String) {
        #expect(text(interval) == expected)
    }

    @Test("minutes bucket", arguments: minutesCases)
    func minutes(interval: TimeInterval, expected: String) {
        #expect(text(interval) == expected)
    }

    @Test("hours bucket", arguments: hoursCases)
    func hours(interval: TimeInterval, expected: String) {
        #expect(text(interval) == expected)
    }

    @Test("days bucket", arguments: daysCases)
    func days(interval: TimeInterval, expected: String) {
        #expect(text(interval) == expected)
    }

    @Test("smallest unit is truncated, never rounded", arguments: truncationCases)
    func truncation(interval: TimeInterval, expected: String) {
        #expect(text(interval) == expected)
    }

    @Test("exact bucket boundaries", arguments: boundaryCases)
    func boundaries(interval: TimeInterval, expected: String) {
        #expect(text(interval) == expected)
    }

    @Test("fractional seconds truncate toward zero", arguments: fractionalCases)
    func fractional(interval: TimeInterval, expected: String) {
        #expect(text(interval) == expected)
    }

    @Test("zero and sub-second intervals render as zero seconds", arguments: zeroCases)
    func zero(interval: TimeInterval) {
        #expect(text(interval) == "0 sec")
    }

    @Test("positive intervals are clamped to zero, not empty", arguments: positiveCases)
    func positiveInput(interval: TimeInterval) {
        #expect(text(interval) == "0 sec")
    }
}
