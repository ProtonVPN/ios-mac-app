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

import Clocks
import Ergonomics
import Testing

struct AsyncSequenceHelpersTests {
    @Test("`when` helper tests")
    func whenHelperTests() async throws {
        let testClock = TestClock()

        // Testing deadline not being hit
        let (s1, c1) = AsyncStream<Int>.makeStream()
        c1.yield(1)

        Task {
            try? await testClock.sleep(for: .milliseconds(100))
            c1.yield(2)
            try? await testClock.sleep(for: .milliseconds(100))
            c1.yield(3)
        }

        Task {
            await testClock.advance(by: .milliseconds(150))
            await testClock.advance(by: .milliseconds(150))
        }

        let s1WaitingStartInstant = testClock.now

        try await s1.when(equals: 3, every: .milliseconds(50), on: testClock, deadline: .seconds(3)) {
            let elapsed = s1WaitingStartInstant.duration(to: testClock.now)
            #expect(elapsed == .milliseconds(200))
        }

        // Testing deadline being hit
        let (s2, c2) = AsyncStream<Int>.makeStream()
        c2.yield(1)

        Task {
            try? await testClock.sleep(for: .milliseconds(100))
            c1.yield(2)
        }

        Task {
            await testClock.advance(by: .seconds(5))
        }

        let s2WaitingStartInstant = testClock.now

        try await s2.when(equals: 3, every: .milliseconds(50), on: testClock, deadline: .seconds(3)) {
            let elapsed = s2WaitingStartInstant.duration(to: testClock.now)
            #expect(elapsed == .seconds(3))
        }

        // Testing throwing error when `performOperationOnDeadlineHit` is `false`
        let (s3, c3) = AsyncStream<Int>.makeStream()
        c3.yield(1)

        Task {
            try? await testClock.sleep(for: .milliseconds(100))
            c3.yield(2)
        }

        Task {
            await testClock.advance(by: .seconds(5))
        }

        await #expect(throws: AsyncSequenceTimeoutError.self) {
            try await s3.when(equals: 3, every: .milliseconds(50), on: testClock, deadline: .seconds(3), performOperationOnDeadlineHit: false) {
                Issue.record("This shouldn't be called and it should have thrown an error.")
            }
        }
    }
}
