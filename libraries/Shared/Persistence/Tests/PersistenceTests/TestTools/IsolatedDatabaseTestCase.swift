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

/// Provides a repository based on an in-memory database specific to each test case (but shared across tests within it).
/// Because of this, it is suitable for tests that either do not modify the repository, or otherwise it should only
/// define a single test that does.
public class IsolatedDatabaseTestCase: XCTestCase {

    fileprivate static var repository: ServerRepository!

    public var sut: ServerRepository { Self.repository }

    public override class func setUp() {
        super.setUp()
        repository = withDependencies {
            $0.appDB = .newInMemoryInstance()
        } operation: {
            ServerRepository.liveValue
        }
    }
}

/// Provides a repository, based on a fresh in-memory database for each test within this test case. Ideal for unit tests
/// that modify the database with a small to medium set of data
public class TestIsolatedDatabaseTestCase: XCTestCase {

    public var sut: ServerRepository!

    public override func setUp() {
        super.setUp()
        sut = withDependencies {
            $0.appDB = .newInMemoryInstance()
        } operation: {
            ServerRepository.liveValue
        }
    }
}


/// Provides an isolated database shared across test within this test case similarly to `IsolatedDatabaseTestCase`, with
/// the addition of initialising it with data loaded from a test resource named after the name of test case class.
///
/// The resource name can be customised by overriding `resourceName`.
public class IsolatedResourceDrivenDatabaseTestCase: IsolatedDatabaseTestCase {

    /// Used to find the resource which contains servers used to initialise this test case with
    public class var resourceName: String {
        String("\(Self.self)".split(separator: ".").last!)
    }

    public override class func setUp() {
        super.setUp()

        let servers = try! loadServers(fromResourceNamed: resourceName)

        try! Self.repository.upsert(servers: servers)
    }

    private static func loadServers(fromResourceNamed name: String) throws -> [VPNServer] {
        let jsonPath = try XCTUnwrap(Bundle.module.path(forResource: name, ofType: "json"))
        let jsonURL = URL(fileURLWithPath: jsonPath)
        let data = try Data(contentsOf: jsonURL)
        return try JSONDecoder().decode([VPNServer].self, from: data)
    }
}
