//
//  Created on 26/08/2025 by adam.
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

import AsyncAlgorithms
import ComposableArchitecture

/// Error thrown when using the ``AsyncSequence.when`` helper and deadline is hit.
public struct AsyncSequenceTimeoutError: Error {}

public extension AsyncSequence where Element: Equatable {
    /// Regularly checks when the underlying value from the sequence satisfies the check.
    /// When the value matches the check, the ``operation`` closure is executed once and the function returns.
    /// If the deadline passes, either throw or perform the ``operation`` based on ``performOperationOnDeadlineHit``.
    /// - Parameters:
    ///   - checkingValue: the value that we'll check against.
    ///   - interval: the interval at which we check if ``deadline`` has passed.
    ///   - clock: the clock on which we base time calculations.
    ///   - deadlineDuration: the deadline that determines at which point we're calling.
    ///   - performOperationOnDeadlineHit: executes the ``operation`` closure or throw an error if `false`. Defaults to `true`.
    ///   - operation: the operation you want to perform.
    func when<C: Clock>(
        equals checkingValue: Element,
        every interval: C.Duration,
        on clock: C = ContinuousClock(),
        deadline deadlineDuration: C.Duration,
        performOperationOnDeadlineHit: Bool = true,
        operation: @escaping () async throws -> Void
    ) async throws where C.Duration: Hashable, Self: Sendable, Element: Sendable {
        try await when(
            willMatch: { $0 == checkingValue },
            every: interval,
            on: clock,
            deadline: deadlineDuration,
            performOperationOnDeadlineHit: performOperationOnDeadlineHit,
            operation: operation
        )
    }
}

public extension AsyncSequence {
    /// Regularly checks when the underlying value from the sequence satisfies the check.
    /// When the value matches the check, the ``operation`` closure is executed once and the function returns.
    /// If the deadline passes, either throw or perform the ``operation`` based on ``performOperationOnDeadlineHit``.
    /// - Parameters:
    ///   - matching: the closure perform with the latest value from the sequence to perform the check.
    ///   - interval: the interval at which we check if ``deadline`` has passed.
    ///   - clock: the clock on which we base time calculations.
    ///   - deadlineDuration: the deadline that determines at which point we're calling.
    ///   - performOperationOnDeadlineHit: executes the ``operation`` closure or throw an error if `false`. Defaults to `true`.
    ///   - operation: the operation you want to perform.
    func when<C: Clock>(
        willMatch matching: (Element) -> Bool,
        every interval: C.Duration,
        on clock: C = ContinuousClock(),
        deadline deadlineDuration: C.Duration,
        performOperationOnDeadlineHit: Bool = true,
        operation: @escaping () async throws -> Void
    ) async throws where C.Duration: Hashable, Self: Sendable, Self.Element: Sendable {
        let combinedSequence = combineLatest(self, clock.timer(interval: interval))
        let deadline = clock.now.advanced(by: deadlineDuration)

        for try await (newValue, _) in combinedSequence {
            try Task.checkCancellation()
            guard clock.now < deadline else {
                if performOperationOnDeadlineHit {
                    try await operation()
                    return
                } else {
                    throw AsyncSequenceTimeoutError()
                }
            }
            guard matching(newValue) else {
                continue
            }
            try await operation()
            return
        }
    }
}
