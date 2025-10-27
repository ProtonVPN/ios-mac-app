//
//  Created on 08/05/2025 by Max Kupetskyi.
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

// MARK: - Private helpers

import AsyncAlgorithms
import ComposableArchitecture

struct SharedReaderTimeoutError: Error {}

extension SharedReader {
    /// Regularly checks when the underlying value satisfies the provided matching condition.
    /// When the value matches (i.e. the matcher returns true), the `operation` closure is executed once with the matched value, and the function returns.
    /// If the deadline passes, the function throws a timeout error.
    /// - Parameters:
    ///   - matcher: A closure that compares the new value and returns true when it matches.
    ///   - interval: The interval at which we check if the deadline has passed.
    ///   - clock: The clock on which we base time calculations.
    ///   - deadlineDuration: The deadline after which the check times out.
    ///   - operation: The operation to perform when a match occurs, receiving the matched value.
    func when<C: Clock>(
        willMatch matcher: @escaping (Value) -> Bool,
        every interval: C.Duration,
        on clock: C = ContinuousClock(),
        deadline deadlineDuration: C.Duration,
        operation: @escaping (Value) async throws -> Void
    ) async throws where C.Duration: Hashable {
        let combinedSequence = combineLatest(publisher.values, clock.timer(interval: interval))
        let deadline = clock.now.advanced(by: deadlineDuration)

        for await (newValue, _) in combinedSequence {
            try Task.checkCancellation()
            guard clock.now < deadline else {
                throw SharedReaderTimeoutError()
            }
            if matcher(newValue) {
                try await operation(newValue)
                return
            }
        }
    }
}
