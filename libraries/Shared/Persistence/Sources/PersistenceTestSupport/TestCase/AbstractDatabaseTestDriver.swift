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

/// Defines shared structure for database test drivers and cases.
///
/// Don't conform to this protocol directly unless you are creating a test driver such as
/// `TestIsolatedDatabaseTestDriver` or a base test case such as `TestIsolatedDatabaseTestCase`.
///
/// This protocol has to be public in order for deriving protocols to also be public.
public protocol AbstractDatabaseTestDriver: AnyObject {

    /// Provides an interface to register callbacks
    var repositoryWrapper: ServerRepositoryWrapper { get }

    /// Use this for tests
    var repository: ServerRepository { get }

    func setUpRepository() throws
    static func setUpRepository() throws
}
