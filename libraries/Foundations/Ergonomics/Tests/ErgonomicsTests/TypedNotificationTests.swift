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

import Foundation
import XCTest
@testable import Ergonomics

private let timeout: TimeInterval = 1.0

extension Array where Element == NotificationToken {
    static func + (_ lhs: Self, _ rhs: NotificationToken) -> Self {
        return lhs + [rhs]
    }

    static func += (_ lhs: inout Self, _ rhs: NotificationToken) {
        lhs = lhs + [rhs]
    }
}

final class TypedNotificationTests: XCTestCase {

    private struct TestNotification: TypedNotification {
        static let name: Notification.Name = Notification.Name("TestNotificationName")
        let data: String
    }

    private struct TestEmptyNotification: EmptyTypedNotification {
        static let name: Notification.Name = Notification.Name("EmptyNotificationName")
    }

    /// Used to verify that notifications are handled according to the object field
    private class TestObject { }

    /// Used to verify and demo retain cycle behaviour
    class TestViewModel: Identifiable {
        var token: NotificationToken?
        var callback: ((String) -> Void)?

        func handleNotification(payload: String) {
            callback?(payload)
        }
    }

    /// Holds tokens for the duration of each test
    private var tokens: [NotificationToken] = []

    override func setUp() {
        tokens = [] // not strictly necessary since tokens are cleared on `tearDown`
    }

    override func tearDown() {
        tokens = []
    }

    /// Handler/token lifetime tests
    func testHandlerLifetime() {
        let notification = TestNotification(data: "Hello, World!")

        // Verify that the token is returned and immediately deallocated
        _ = NotificationCenter.default.addObserver(for: TestNotification.self, object: self) { data in
            XCTFail("Handler should not be invoked since token is immediately deallocated")
        }

        NotificationCenter.default.post(notification, object: nil)

        // Register a token and hold onto it - handler should fire
        var token: NotificationToken?
        var blockToExecuteOnNotification: ((String) -> Void)?
        token = NotificationCenter.default.addObserver(for: TestNotification.self, object: nil) { data in
            blockToExecuteOnNotification?(data)
        }

        let handlerInvocation = XCTestExpectation(description: "Handler should have been invoked: token is in scope")
        blockToExecuteOnNotification = { receivedNotificationData in
            XCTAssertEqual(receivedNotificationData, notification.data)
            handlerInvocation.fulfill()
        }

        NotificationCenter.default.post(notification, object: nil)
        wait(for: [handlerInvocation], timeout: timeout)

        // Deallocate token - handler should no longer fire
        token = nil
        blockToExecuteOnNotification = { _ in
            XCTFail("Handler should not have been invoked: token has been deallocated")
        }

        NotificationCenter.default.post(notification, object: nil)

        XCTAssertNil(token) // dumb way to silence unread variable warning (token was assigned to but never read)
    }

    /// Demonstrates automatic deallocation of token when using a weak reference to the token's owner in the handler
    /// We're testing the `NotificationCenter` and the Swift weak/strong reference system here and not
    /// `TypedNotification` logic, but it's a good demo.
    func testUsingWeakReferenceAvoidsRetainCycle() throws {
        // Hold weak references to objects that register a notification handler and hold a `NotificationToken`
        weak var weakVM: TestViewModel?
        weak var strongVM: TestViewModel?

        let closure: () -> Void = {
            let weaklyReferencedVM = TestViewModel()
            let stronglyReferencedVM = TestViewModel()

            weakVM = weaklyReferencedVM
            strongVM = stronglyReferencedVM

            weaklyReferencedVM.token = NotificationCenter.default.addObserver(
                for: TestNotification.self,
                object: nil
            ) { [weak weaklyReferencedVM] payload in
                weaklyReferencedVM?.handleNotification(payload: payload)
            }

            weaklyReferencedVM.callback = { _ in
                XCTFail("This VM should be immediately deallocated so the handler should never be invoked")
            }

            stronglyReferencedVM.token = NotificationCenter.default.addObserver(
                for: TestNotification.self,
                object: nil
            ) { [stronglyReferencedVM] payload in
                stronglyReferencedVM.handleNotification(payload: payload)
            }
        }

        // Create test view models in a nested scope
        closure()
        XCTAssertNil(weakVM, "Should have been immediately deallocated since we only have a weak reference to it")
        XCTAssertNotNil(strongVM, "Should have been retained due to a retain cycle with its token's observer")

        // Post a notification to make sure the notification handlers are (not) retained
        let handlerInvocation = XCTestExpectation(description: "VM with retain cycle should react to the notification")
        try XCTUnwrap(strongVM).callback = { _ in handlerInvocation.fulfill() }

        NotificationCenter.default.post(TestNotification(data: "hello"), object: nil)
        wait(for: [handlerInvocation])

        strongVM?.token = nil
        XCTAssertNil(strongVM, "Retain cycle should be broken once the token is manually removed")

        NotificationCenter.default.post(TestNotification(data: "hello"), object: nil)
    }

    func testInvokedWithEmptyNotification() {
        let notification = TestEmptyNotification()

        let handlerInvocation = XCTestExpectation(description: "Handler for empty notification should be called")

        tokens += NotificationCenter.default.addObserver(for: TestEmptyNotification.self, object: self) {
            handlerInvocation.fulfill()
        }

        NotificationCenter.default.post(notification, object: self)
        wait(for: [handlerInvocation], timeout: timeout)
    }

    func testNotificationPayload() {
        let notification = TestNotification(data: "Hello, World!")

        tokens += NotificationCenter.default.addObserver(for: TestNotification.self, object: nil) { payload in
            XCTAssertEqual(payload, notification.data)
        }

        NotificationCenter.default.post(notification, object: nil)
    }

    func testPostedNotificationCausesHandlerInvocationForCorrectObjects() {
        let anyInvocation = XCTestExpectation(description: "Handler should always be invoked when not constraining poster.")
        let posterInvocation = XCTestExpectation(description: "Handler should be invoked.")

        let notification = TestNotification(data: "some notification data")

        let poster = TestObject()
        let other = TestObject()

        tokens += NotificationCenter.default.addObserver(for: TestNotification.self, object: nil) { _ in
            anyInvocation.fulfill()
        }

        tokens += NotificationCenter.default.addObserver(for: TestNotification.self, object: poster) { _ in
            posterInvocation.fulfill()
        }

        tokens += NotificationCenter.default.addObserver(for: TestNotification.self, object: other) { _ in
            // Notification was posted with object: `poster`, so only observers for `nil` or `poster` should react.
            XCTFail("Handler invoked for observer with incorrect object")
        }

        NotificationCenter.default.post(notification, object: poster)

        wait(for: [anyInvocation, posterInvocation], timeout: timeout)
    }

    /// Test that programmer errors are caught when misusing typed notifications. In fact, this shouldn't even be
    /// possible unless someone chooses to manually send a typed notification using the default NotificationCenter API
    /// instead of the post(_: TypedNotification, object: Any) overload.
    func testHandlerNotInvokedWithBadData() {
        tokens += NotificationCenter.default.addObserver(for: TestNotification.self, object: self) { data in
            XCTFail("Handlers should not be invoked with missing or mismatched data: \(data)")
        }

        XCTExpectFailure("Post should fail with incorrectly typed data", enabled: true, strict: true, failingBlock: {
            // post notification with data of incorrect type
            NotificationCenter.default.post(
                name: TestNotification.name,
                object: self,
                userInfo: [TestNotification.dataKey: 123] // Provide Int instead of the expected String
            )
        }, issueMatcher: { issue in
            return issue.compactDescription == "Expected object of type String stored under key: ch.protonvpn.notificationcenter.notificationdata, got 123"
        })

        XCTExpectFailure("Post should fail with missing data", enabled: true, strict: true, failingBlock: {
            // post notification with missing data
            NotificationCenter.default.post(name: TestNotification.name, object: self, userInfo: [:])
        }, issueMatcher: { issue in
            return issue.compactDescription == "Expected object of type String stored under key: ch.protonvpn.notificationcenter.notificationdata, got nil"
        })
    }
}
