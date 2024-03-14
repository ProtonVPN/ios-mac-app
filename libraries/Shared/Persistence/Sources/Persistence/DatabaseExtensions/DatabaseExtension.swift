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

/// Used to define pure database functions that require a `@Dependency` to precompute information.
///
/// These cannot be a lazily generated `GRDB.DatabaseFunction`, because their implementation depends on a `@Dependency`.
/// This means that they must be re-created every time we create a `DatabaseQueue`, but not when these functions are
/// used in GRDB's Query Interface, since this would negate any performance improvements we gain through precomputing.
/// The alternative to doing this would be to have `Database` or `DatabaseConfig` hold these `DatabaseFunction`
/// instances, and refer to them also using `@Dependency`.
///
/// Usage:
/// - Construct a global instance of DatabaseExtension.
///   ```
///   private func generator() -> DatabaseExecutable  { ... } // something that uses a @Dependency to pre-compute a
///   let incrementer = DatabaseExtension(name: "INC", argumentCount: 1, isPure: true, implementationGenerator: generator)
///   ```
///
/// - Use `createFunctionForRegistration` when configuring databases. This initialises and this passes the real
///   implementation to SQL, based on the current `@Dependency` values.
///   ```
///   config.prepareDatabase { db in
///       db.add(function: localizedCountryName.functionForRegistration())
///   }
///   ```
///
/// - Use this instance to evaluate some `SQLExpression` e.g. to transform columns in Interface Query language. GRDB
///   translates the query, which is evaluated using the registered function implementation without us having to compute
///   `generator` again.
///   ```
///   Int.fetchAll(incrementer(sqlExpression)
///   ```
struct DatabaseExtension {
    private let name: String
    private let argumentCount: Int
    private let isPure: Bool
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

    /// Creates a `DatabaseFunction` instance, passing the real implementation that is created with the current
    /// `@Dependency` environment. This is the implementation that is executed by the database whenever this instance
    /// is used to  evaluate `SQLExpressions` using `callAsFunction`
    ///
    /// Do **NOT** use this to evaluate `SQLExpressions`, it will evaluate `implementationGenerator` for no reason.
    func createFunctionForRegistration() -> DatabaseFunction {
        DatabaseFunction(name, argumentCount: argumentCount, pure: isPure, function: implementationGenerator())
    }

    /// Use the `DatabaseFunction` created with a placeholder implementation to allow GRDB to evaluate SQL expressions
    /// involving this function, without invoking the precomputation in `implementationGenerator`.
    func callAsFunction(_ arguments: any SQLExpressible) -> SQLExpression {
        return placeholderFunction.callAsFunction(arguments)
    }

    private static var placeholderImplementation: DatabaseExecutable {
        return { _ in
            throw DatabaseExtensionError.placeholderInvoked
        }
    }
}

enum DatabaseExtensionError: Error {
    case placeholderInvoked
}
