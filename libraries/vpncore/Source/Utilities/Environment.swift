//
//  Created on 24/03/2023.
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

/// Provides a way to test error paths that crash DEBUG builds by overriding the assertionFailure behaviour in tests.
public class Environment {
    public private (set) static var _assertionFailure = assertionFailure
    public private (set) static var _assert = assert

    private static let environmentQueue = DispatchQueue(label: "ch.protonvpn.test.environment")

    /// Executes the given closure, causing any `_assertionFailure` and failed `_assert` calls to call `errorBlock`.
    ///
    /// Use this to test error paths that should crash DEBUG builds. This runs synchronously on an `environmentQueue`
    ///
    /// - Important: Never use this outside of tests.
    public static func execute(_ block: () -> Void, catchingAssertionFailuresWith errorBlock: @escaping () -> Void) {
        environmentQueue.sync {
            Self._assert = { condition, _, _, _ in
                if !condition() {
                    errorBlock()
                }
            }
            Self._assertionFailure = { _, _, _ in errorBlock() }

            block()

            Self._assert = assert
            Self._assertionFailure = assertionFailure
        }
    }
}
