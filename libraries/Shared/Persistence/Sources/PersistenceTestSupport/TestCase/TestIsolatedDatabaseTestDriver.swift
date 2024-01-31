//
//  Created on 12/02/2024.
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

/// Provides a repository, instantiated with a fresh in-memory database for each test within this test case.
///
/// It is recommended to extend `TestIsolatedDatabaseTestCase` instead of conforming to this protocol, if you can.
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
