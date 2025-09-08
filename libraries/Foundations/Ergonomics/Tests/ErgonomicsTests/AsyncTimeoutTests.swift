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
import Ergonomics
import Testing

/// A simple error that can be thrown from an async function.
private struct WorkError: Error {}

/// A unit of work in an async function form; the sleep is performed directly by the Task (thus not controllable).
private func work(of duration: Duration) async throws {
    try await Task.sleep(for: duration)
}

/// A unit of customizable work in an async function form; the sleep is performed by a clock that can be injected via
/// swift-dependencies.
private func clockWork<T>(of duration: Duration, do work: () throws -> T) async throws -> T {
    @Dependency(\.continuousClock) var clock
    try await clock.sleep(for: duration)
    return try work()
}

struct AsyncTimeoutTests {
    @Test("`withSimpleTimeoutTest` helper test")
    func withSimpleTimeoutTest() async throws {
        let clock = TestClock()

        await withDependencies {
            $0.continuousClock = clock
        } operation: {
            Task {
                await clock.advance(by: .seconds(5))
            }

            await #expect(throws: AsyncTimeoutError.self) {
                try await withTimeout(of: .seconds(3)) {
                    try await clockWork(of: .seconds(10)) { // ideally, this should be `work` instead of `clockWork`
                        if !Task.isCancelled {
                            Issue.record("This shouldn't be called and it should have thrown an error.")
                        }
                    }
                }
            }
        }
    }

    @Test("`withSimpleTimeoutThrowingError` helper test")
    func withSimpleTimeoutThrowingError() async throws {
        let clock = TestClock()

        await withDependencies {
            $0.continuousClock = clock
        } operation: {
            Task {
                await clock.advance(by: .seconds(5))
            }

            await #expect(throws: AsyncTimeoutError.self) {
                try await withTimeout(of: .seconds(3)) {
                    try await clockWork(of: .seconds(10)) { // ideally, this should be `work` instead of `clockWork`
                        if !Task.isCancelled {
                            Issue.record("This shouldn't be called and it should have thrown an error.")
                        }
                    }
                }
            }
        }
    }

    @Test("`withTimeoutWorkDoneAssertingElapsedTime` helper test")
    func withTimeoutWorkDoneAssertingElapsedTime() async throws {
        let clock = TestClock()

        try await withDependencies {
            $0.continuousClock = clock
        } operation: {
            let start = clock.now
            var workDoneInstantOptional: TestClock<Duration>.Instant?

            Task {
                await clock.advance(by: .seconds(10))
            }

            let value = try await withTimeout(of: .seconds(5)) {
                try await clockWork(of: .seconds(1), do: {
                    workDoneInstantOptional = clock.now
                    return 42
                })
            }
            #expect(value == 42)
            let workDoneInstant = try #require(workDoneInstantOptional)
            let elapsed = start.duration(to: workDoneInstant)
            #expect(elapsed == .seconds(1))
        }
    }

    @Test("`withNestedTimeoutsThrowingError` helper test")
    func withNestedTimeoutsThrowingError() async throws {
        let clock = TestClock()

        await withDependencies {
            $0.continuousClock = clock
        } operation: {
            Task {
                await clock.advance(by: .seconds(10))
            }

            await #expect(throws: AsyncTimeoutError.self) {
                try await withTimeout(of: .seconds(5)) {
                    try await withTimeout(of: .seconds(2)) {
                        try await clockWork(of: .seconds(3)) {
                            42
                        }
                    }
                }
            }
        }
    }

    @Test("`withNestedTimeoutsWorkDoneAssertingElapsedTime` helper test")
    func withNestedTimeoutsWorkDoneAssertingElapsedTime() async throws {
        let clock = TestClock()

        try await withDependencies {
            $0.continuousClock = clock
        } operation: {
            let start = clock.now
            var workDoneInstantOptional: TestClock<Duration>.Instant?

            Task {
                await clock.advance(by: .seconds(10))
            }

            let value = try await withTimeout(of: .seconds(5)) {
                workDoneInstantOptional = clock.now
                return try await withTimeout(of: .seconds(8)) {
                    workDoneInstantOptional = clock.now
                    return try await clockWork(of: .seconds(4)) {
                        workDoneInstantOptional = clock.now
                        return 42
                    }
                }
            }

            #expect(value == 42)
            let workDoneInstant = try #require(workDoneInstantOptional)
            let elapsed = start.duration(to: workDoneInstant)
            #expect(elapsed == .seconds(4))
        }
    }

    @Test("`withTimeoutWorkDoneRethrowingWorkError` helper test")
    func withTimeoutWorkDoneRethrowingWorkError() async throws {
        let t5Clock = TestClock()

        await withDependencies {
            $0.continuousClock = t5Clock
        } operation: {
            Task {
                await t5Clock.advance(by: .seconds(5))
            }

            await #expect(throws: WorkError.self) {
                try await withTimeout(of: .seconds(10)) {
                    try await clockWork(of: .seconds(3)) { throw WorkError() }
                }
            }
        }
    }
}
