//
//  Created on 14/03/2024.
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

import GRDB

typealias DatabaseExecutable = ([DatabaseValue]) throws -> String

/// Used to define pure database functions that require dependencies to pre-bake information.
///
/// This manages
struct DatabaseExtension {
    private let name: String
    private let argumentCount: Int
    private let isPure: Bool

    /// Computed once per database queue initialisation.
    ///
    /// This cannot be a lazy var since we sometimes want to create additional databases that use a different country
    /// name localization implementation, e.g. for tests.
    private let implementationGenerator: () -> DatabaseExecutable

    private let placeholderFunction: DatabaseFunction

    init(
        name: String,
        argumentCount: Int,
        isPure: Bool,
        implementationGenerator: @escaping () -> DatabaseExecutable
    ) {
        self.name = name
        self.argumentCount = argumentCount
        self.isPure = isPure
        self.implementationGenerator = implementationGenerator

        self.placeholderFunction = DatabaseFunction(
            name,
            argumentCount: argumentCount,
            pure: isPure,
            function: Self.placeholderImplementation
        )
    }
}

extension DatabaseExtension {

    func functionForRegistration() -> DatabaseFunction {
        DatabaseFunction(name, argumentCount: argumentCount, pure: isPure, function: implementationGenerator())
    }

    func callAsFunction(_ arguments: any SQLExpressible) -> SQLExpression {
        placeholderFunction(arguments)
    }

    private static var placeholderImplementation: DatabaseExecutable {
        return { _ in
            assertionFailure("Placeholder implementations should never be executed")
            return ""
        }
    }
}
