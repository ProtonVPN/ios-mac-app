//
//  Created on 05/09/2025 by adam.
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

import Clocks
import Dependencies
import os

/// Error thrown when using the ``withTimeout`` helper and deadline is hit.
public struct AsyncTimeoutError: Swift.Error {}

private actor TimeoutCoordinator {
    private var hasCompleted = false

    func tryComplete() -> Bool {
        if hasCompleted {
            return false
        }
        hasCompleted = true
        return true
    }
}

/// Executes an async operation with a timeout, throwing an error if the operation doesn't complete within the specified duration.
///
/// ## Example
///
/// ```swift
/// do {
///     let result = try await withTimeout(of: .seconds(5)) {
///         try await someNetworkCall()
///     }
/// } catch is AsyncTimeoutError {
///     print("Network call timed out")
/// } catch {
///     print("Network call failed: \(error)")
/// }
/// ```
///
/// - Parameters:
///   - timeoutDuration: The maximum duration to wait for the work to complete.
///   - work:  An async throwing closure that performs the work to be timed.
///   - cancellationHandler: An optional closure called when the operation is cancelled from outside.
/// - Throws: `AsyncTimeoutError`` if the timeout elapses, or any error thrown by the work closure.
/// - Returns: The result of the work closure if it completes within the timeout.
public func withTimeout<ReturnType: Sendable>(
    of timeoutDuration: Duration,
    perform work: @escaping () async throws -> ReturnType,
    cancellationHandler: (() -> Void)? = nil
) async throws -> ReturnType {
    @Dependency(\.continuousClock) var clock

    let anyClock = AnyClock(clock)

    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = TimeoutCoordinator()

            let workTask = Task {
                do {
                    let result = try await work()
                    if await coordinator.tryComplete() {
                        continuation.resume(returning: result)
                    }
                } catch {
                    if await coordinator.tryComplete() {
                        continuation.resume(throwing: error)
                    }
                }
            }

            Task {
                try await anyClock.sleep(for: timeoutDuration)
                workTask.cancel()
                if await coordinator.tryComplete() {
                    continuation.resume(throwing: AsyncTimeoutError())
                }
            }
        }
    } onCancel: {
        cancellationHandler?()
    }
}
