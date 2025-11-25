//
//  Created on 24/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

import AsyncAlgorithms
import ComposableArchitecture

/// Error thrown when using the ``SharedReader.when`` helper and deadline is hit.
struct SharedReaderTimeoutError: Error {}

package extension Shared where Value: Equatable {
    /// Regularly checks when the underlying value satisfies the check.
    /// When the value matches the check, the ``operation`` closure is executed once and the function returns.
    /// If the deadline passes, the ``operation`` closure is executed once and the function returns.
    /// - Parameters:
    ///   - checkingValue: the value that we'll check against.
    ///   - interval: the interval at which we check if ``deadline`` has passed.
    ///   - clock: the clock on which we base time calculations.
    ///   - deadlineDuration: the deadline that determines at which point we're calling.
    ///   - operation: the operation that will be performed.
    func when<C: Clock>(
        equals checkingValue: Value,
        every interval: C.Duration,
        on clock: C = ContinuousClock(),
        deadline deadlineDuration: C.Duration,
        operation: @escaping () async throws -> Void
    ) async throws where C.Duration: Hashable {
        let combinedSequence = combineLatest(publisher.values, clock.timer(interval: interval))
        let deadline = clock.now.advanced(by: deadlineDuration)

        for await (newValue, _) in combinedSequence {
            try Task.checkCancellation()
            guard clock.now < deadline else {
                throw SharedReaderTimeoutError()
            }
            guard newValue == checkingValue else {
                continue
            }
            try await operation()
            return
        }
    }
}

package extension SharedReader where Value: CasePathable {
    /// Regularly checks when the underlying value satisfies the check.
    /// When the value matches the check, the ``operation`` closure is executed once and the function returns.
    /// If the deadline passes, the ``operation`` closure is executed once and the function returns.
    /// - Parameters:
    ///   - caseKeyPath: the ``PartialCaseKeyPath`` that will allow to perform the check on the `newValue`.
    ///   - interval: the interval at which we check if ``deadline`` has passed.
    ///   - clock: the clock on which we base time calculations.
    ///   - deadlineDuration: the deadline that determines at which point we're calling.
    ///   - operation: the operation that will be performed.
    func when<C: Clock>(
        willBe caseKeyPath: PartialCaseKeyPath<Value>,
        every interval: C.Duration,
        on clock: C = ContinuousClock(),
        deadline deadlineDuration: C.Duration,
        operation: @escaping () async throws -> Void
    ) async throws where C.Duration: Hashable {
        let combinedSequence = combineLatest(publisher.values, clock.timer(interval: interval))
        let deadline = clock.now.advanced(by: deadlineDuration)

        for await (newValue, _) in combinedSequence {
            try Task.checkCancellation()
            guard clock.now < deadline else {
                throw SharedReaderTimeoutError()
            }
            guard newValue.is(caseKeyPath) else {
                continue
            }
            try await operation()
            return
        }
    }
}

package extension SharedReader where Value: Equatable {
    /// Regularly checks when the underlying value satisfies the check.
    /// When the value matches the check, the ``operation`` closure is executed once and the function returns.
    /// If the deadline passes, the ``operation`` closure is executed once and the function returns.
    /// - Parameters:
    ///   - checkingValue: the value that we'll check against.
    ///   - interval: the interval at which we check if ``deadline`` has passed.
    ///   - clock: the clock on which we base time calculations.
    ///   - deadlineDuration: the deadline that determines at which point we're calling.
    ///   - operation: the operation you want to perform.
    func when<C: Clock>(
        equals checkingValue: Value,
        every interval: C.Duration,
        on clock: C = ContinuousClock(),
        deadline deadlineDuration: C.Duration,
        operation: @escaping () async throws -> Void
    ) async throws where C.Duration: Hashable {
        let combinedSequence = combineLatest(publisher.values, clock.timer(interval: interval))
        let deadline = clock.now.advanced(by: deadlineDuration)

        for await (newValue, _) in combinedSequence {
            try Task.checkCancellation()
            guard clock.now < deadline else {
                throw SharedReaderTimeoutError()
            }
            guard newValue == checkingValue else {
                continue
            }
            try await operation()
            return
        }
    }
}
