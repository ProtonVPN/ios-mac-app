//
//  Created on 15/06/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ConcurrencyExtras
import Foundation

/// Tracks the last value forwarded through a `UserDefaults`-backed stream and reports whether a new
/// value differs from it
public struct ChangeGate<Value: Sendable>: Sendable {
    private let previous: LockIsolated<Value>

    public init(initial: Value) {
        self.previous = LockIsolated(initial)
    }

    /// Returns `true` — and stores `newValue` when `newValue` differs from the
    /// last value seen; `false` when it is an duplicate
    public func isChange(_ newValue: Value) -> Bool {
        previous.withValue { last in
            if Self.valuesAreEqual(newValue, last) == true {
                return false
            }
            last = newValue
            return true
        }
    }

    private static func valuesAreEqual(_ lhs: Value, _ rhs: Value) -> Bool? {
        // `Value` is usually an `Optional` (e.g. `NATType?`, `Bool?`)
        let lhsIsNil = (lhs as? any OptionalProtocol)?.isNil ?? false
        let rhsIsNil = (rhs as? any OptionalProtocol)?.isNil ?? false
        if lhsIsNil || rhsIsNil {
            return lhsIsNil == rhsIsNil // both nil -> equal; exactly one nil -> not equal
        }
        guard let lhs = lhs as? any Equatable else { return nil }
        func open<U: Equatable>(_ lhs: U) -> Bool {
            lhs == rhs as? U
        }
        return open(lhs)
    }
}

private protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool {
        self == nil
    }
}
