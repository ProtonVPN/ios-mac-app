//
//  Created on 7/26/24.
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

import Ergonomics
import PersistenceTestSupport
@testable import Persistence

final class MetadataTests: TestIsolatedDatabaseTestCase {

    func testStoreRetrieveAndDeleteMetadata() throws {
        let valueToStore = DateFormatter.imf.string(from: Date())
        repository.setMetadata(.lastModified, valueToStore)

        let result = repository.getMetadata(.lastModified)
        let valueRetrieved = try XCTUnwrap(result)

        XCTAssertEqual(valueToStore, valueRetrieved)

        // Let's check that storing nil deletes the existing value for this key
        repository.setMetadata(.lastModified, nil)
        XCTAssertNil(repository.getMetadata(.lastModified))
    }
}
