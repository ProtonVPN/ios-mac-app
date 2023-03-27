//
//  Created on 08/03/2023.
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

import XCTest
@testable import vpncore

final class ProtonNotificationTests: XCTestCase {

    struct TestNotification: StrongNotification {
        static let name: Notification.Name = Notification.Name("TestNotificationName")
        let data: String
    }

    struct EmptyNotification: StrongNotification {
        static let name: Notification.Name = Notification.Name("EmptyNotificationName")
        let data: Void
    }

    class TestObject { }

    func testHandlerNotInvokedAfterTokenIsDeallocated() {
        let handlerInvoked = XCTestExpectation(description: "Handler should not be invoked if token has been deallocated")
        handlerInvoked.isInverted = true

        let notification = TestNotification(data: "some notification data")

        // token is returned and immediately deallocated
        _ = NotificationCenter.default.addObserver(for: TestNotification.self, object: self) { data in
            handlerInvoked.fulfill()
        }

        NotificationCenter.default.post(notification, object: self)

        wait(for: [handlerInvoked], timeout: 0.1)
    }

    func testPostedNotificationCausesHandlerInvocationForCorrectObjects() {
        let anyInvocation = XCTestExpectation(description: "Handler should always be invoked when not constraining poster.")
        let posterInvocation = XCTestExpectation(description: "Handler should be invoked.")
        let otherInvocation = XCTestExpectation(description: "Handler should not be invoked for different object.")
        otherInvocation.isInverted = true

        let notification = TestNotification(data: "some notification data")

        let poster = TestObject()
        let other = TestObject()

        let token1 = NotificationCenter.default.addObserver(for: TestNotification.self, object: nil) { data in
            anyInvocation.fulfill()
        }

        let token2 = NotificationCenter.default.addObserver(for: TestNotification.self, object: poster) { data in
            XCTAssertEqual(notification.data, data)
            posterInvocation.fulfill()
        }

        let token3 = NotificationCenter.default.addObserver(for: TestNotification.self, object: other) { data in
            otherInvocation.fulfill()
        }

        NotificationCenter.default.post(notification, object: poster)

        wait(for: [anyInvocation, posterInvocation, otherInvocation], timeout: 0.1)
    }

    func testHandlerNotInvokedWithBadData() {
        let handlerInvocation = XCTestExpectation(description: "Assertion failure should be triggered missing data or type mistmatches")
        handlerInvocation.expectedFulfillmentCount = 2

        Environment.execute({
            let token = NotificationCenter.default.addObserver(for: TestNotification.self, object: self) { data in
                XCTFail("Handlers should not be invoked with missing or mismatched data: \(data)")
            }

            // post notification with data of incorrect type
            NotificationCenter.default.post(name: TestNotification.name, object: self, userInfo: [TestNotification.dataKey: 123])

            // post notification with missing data
            NotificationCenter.default.post(name: TestNotification.name, object: self, userInfo: [:])

        }, catchingAssertionFailuresWith: {
            handlerInvocation.fulfill()
        })

        wait(for: [handlerInvocation], timeout: 0.1)
    }
}
