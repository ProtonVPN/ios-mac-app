//
//  Created on 27/01/2024.
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

import Foundation
import XCTest

import Dependencies

import Persistence

/// Provides a repository, based on a fresh in-memory database shared between all tests within this test case. Ideal for
/// a set of tests that operates on the same set of data. If your data set isn't big (it shouldn't be for unit tests),
/// or you don't have a lot of tests within this case you should consider using `TestIsolatedDatabaseTestCase`.
///
/// If you must extend a different `XCTestCase` subclass, you can conform to `CaseIsolatedDatabaseTestDriver` instead.
open class CaseIsolatedDatabaseTestCase: XCTestCase, CaseIsolatedDatabaseTestDriver {
    public static var internalRepository: ServerRepository!
    public static var internalRepositoryWrapper: ServerRepositoryWrapper!

    open override class func setUp() {
        super.setUp()
        setUpRepository()
    }

    open override func invokeTest() {
        withDependencies {
            $0.serverRepository = repository
        } operation: {
            super.invokeTest()
        }
    }
}

/// Provides a repository, based on a fresh in-memory database for each test within this test case. Ideal for unit tests
/// that modify the database with a small to medium set of data.
///
/// If you must extend a different `XCTestCase` subclass, you can conform to `TestIsolatedDatabaseTestDriver` instead.
open class TestIsolatedDatabaseTestCase: XCTestCase, TestIsolatedDatabaseTestDriver {
    public var internalRepositoryWrapper: ServerRepositoryWrapper?
    public var internalRepository: ServerRepository?

    open override func invokeTest() {
        try! setUpRepository()
        withDependencies {
            $0.serverRepository = repository
        } operation: {
            super.invokeTest()
        }
    }
}
