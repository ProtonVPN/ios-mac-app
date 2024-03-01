//
//  Created on 31/01/2024.
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

import Dependencies

import Persistence

/// Provides a repository, based on a fresh in-memory database shared between all tests within this test case. Ideal for
/// a set of tests that operates on the same set of data. If your data set isn't big (it shouldn't be for unit tests),
/// or you don't have a lot of tests within this case you should consider using `TestIsolatedDatabaseTestDriver`.
///
/// It is recommended to extend `CaseIsolatedDatabaseTestCase` instead of conforming to this protocol, if you can.
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
            $0.databaseConfiguration = .withTestExecutor(databaseType: .ephemeral)
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
