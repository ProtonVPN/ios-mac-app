//
//  Created on 05/07/2024.
//
//  Copyright (c) 2024 Proton AG
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

import XCTest

import Combine
@testable import Ergonomics

final class AsyncStreamTests: XCTestCase {
    func testAwareAsyncStream() async throws {
        let numbers: [Int] = [1, 2, 3, 4, 5]
        let awareStream = AwareAsyncStream(numbers.publisher.values)
        XCTAssertFalse(awareStream.hasBeenListened)
        var count: Int = 0
        for await value in awareStream {
            XCTAssertTrue(numbers.contains(value))
            XCTAssertTrue(awareStream.hasBeenListened)
            count += 1
        }
        XCTAssertTrue(awareStream.hasBeenListened)
        XCTAssertEqual(count, numbers.count)
    }

    func testAwareAsyncThrowingStream() async throws {
        enum CustomError: Swift.Error {
            case anError
        }
        var streamCounter = 1
        let throwingValue = Int.random(in: 2...10)
        let stream = AsyncThrowingStream {
            defer { streamCounter += 1 }
            if streamCounter == throwingValue {
                throw CustomError.anError
            }
            return streamCounter
        }

        let awareStream = AwareAsyncThrowingStream(stream)
        XCTAssertFalse(awareStream.hasBeenListened)
        var testingCounter: Int = 1

        await XCTAssertThrowsError({
            for try await value in awareStream {
                XCTAssertEqual(value, testingCounter)
                XCTAssertTrue(awareStream.hasBeenListened)
                testingCounter += 1
            }
        }, "Expected to receive a \(String(describing: type(of: CustomError.anError))) error") { error in
            XCTAssertNotNil(error as? CustomError)
        }

        XCTAssertEqual(testingCounter, throwingValue)
        XCTAssertTrue(awareStream.hasBeenListened)
    }
}
