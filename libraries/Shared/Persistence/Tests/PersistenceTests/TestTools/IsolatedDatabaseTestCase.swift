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

import Domain

import Dependencies

@testable import Persistence

public protocol AbstractDatabaseTestDriver: AnyObject {
    /// Provides an interface to register callbacks
    var repositoryWrapper: ServerRepositoryWrapper { get }
    /// Use this for tests
    var repository: ServerRepository { get }

    func setUpRepository() throws
    static func setUpRepository() throws
}

public protocol TestIsolatedDatabaseTestDriver: AbstractDatabaseTestDriver {
    var internalRepositoryWrapper: ServerRepositoryWrapper? { get set }
    var internalRepository: ServerRepository? { get set }
}

extension TestIsolatedDatabaseTestDriver {

    private var setUpErrorMessage: String {
        "Did you forget to invoke `setUpRepository()` in your test case's overridden `setUp` or `setUpWithError` method?"
    }

    public var repositoryWrapper: ServerRepositoryWrapper {
        assert(internalRepositoryWrapper != nil, setUpErrorMessage)
        return internalRepositoryWrapper!
    }

    public var repository: ServerRepository {
        assert(internalRepository != nil, setUpErrorMessage)
        return internalRepository!
    }

    public func setUpRepository() throws {
        let repositoryImplementation = withDependencies {
            $0.appDB = .newInMemoryInstance()
        } operation: {
            ServerRepository.liveValue
        }

        internalRepositoryWrapper = ServerRepositoryWrapper(repository: repositoryImplementation)
        internalRepository = .wrapped(wrappedWith: internalRepositoryWrapper!)
    }

    public static func setUpRepository() throws {
        assertionFailure("Invoke the instance version of this method in the `XCTestCase` instance method `setUp()``")
    }
}

/// Provides a repository based on an in-memory database specific to each test case (but shared across tests within it).
/// Because of this, it is suitable for tests that either do not modify the repository, or otherwise it should only
/// define a single test that does.
public protocol CaseIsolatedDatabaseTestDriver: AbstractDatabaseTestDriver {
    static var internalRepository: ServerRepository! { get set }
    static var internalRepositoryWrapper: ServerRepositoryWrapper! { get set }
}

extension CaseIsolatedDatabaseTestDriver {
    private var setUpErrorMessage: String {
        "Did you forget to invoke the static `setUpRepository()` in your test case's overridden `setUp` class method?"
    }

    public static func setUpRepository() {
        let repositoryImplementation = withDependencies {
            $0.appDB = .newInMemoryInstance()
        } operation: {
            ServerRepository.liveValue
        }

        internalRepositoryWrapper = ServerRepositoryWrapper(repository: repositoryImplementation)
        internalRepository = .wrapped(wrappedWith: internalRepositoryWrapper!)
    }

    public var repository: ServerRepository {
        assert(Self.internalRepository != nil, setUpErrorMessage)
        return Self.internalRepository!
    }

    public var repositoryWrapper: ServerRepositoryWrapper {
        assert(Self.internalRepository != nil, setUpErrorMessage)
        return Self.internalRepositoryWrapper!
    }

    public func setUpRepository() throws {
        assertionFailure("Invoke the static version of this method in the class method `XCTestCase.setUp()`")
    }
}

/// Provides a repository, based on a fresh in-memory database for each test within this test case. Ideal for unit tests
/// that modify the database with a small to medium set of data
public class CaseIsolatedDatabaseTestCase: XCTestCase, CaseIsolatedDatabaseTestDriver {
    public static var internalRepository: ServerRepository!
    public static var internalRepositoryWrapper: ServerRepositoryWrapper!

    public override class func setUp() {
        super.setUp()
        setUpRepository()
    }
}

public class TestIsolatedDatabaseTestCase: XCTestCase, TestIsolatedDatabaseTestDriver {
    public var internalRepositoryWrapper: ServerRepositoryWrapper?
    public var internalRepository: ServerRepository?

    public override func setUpWithError() throws {
        try super.setUpWithError()
        try setUpRepository()
    }
}
