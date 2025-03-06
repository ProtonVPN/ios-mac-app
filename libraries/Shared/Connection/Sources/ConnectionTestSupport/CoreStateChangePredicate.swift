//
//  Created on 02/03/2025.
//
//  Copyright (c) 2025 Proton AG
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
import CasePaths
import Connection

/// Helper for asserting that delegate `stateChanged` actions are received with the expected state transition
/// - Parameters:
///   - extract: closure that pulls out core connection states from the generic `Action` parameter
///   - strict: When `true`, a failure will be raised whenever a `stateChanged` action is received between states
///   other than the ones specified.
/// - Returns: A predicate that suitable for asserting that a state change action was received between specific
///   states.
public func stateChangePredicate<Action>(
    from oldValue: PartialCaseKeyPath<CoreConnectionState>,
    to newValue: PartialCaseKeyPath<CoreConnectionState>,
    extract: @escaping (Action) -> (CoreConnectionState, CoreConnectionState)?,
    strict: Bool = true
) -> (Action) -> Bool {
    return { action in
        guard let (oldState, newState) = extract(action) else {
            return false
        }
        if oldState.is(oldValue) && newState.is(newValue) {
            return true
        }
        if strict {
            let oldStateName = caseName(of: oldState)
            let newStateName = caseName(of: newState)
            XCTFail("Received core state change action, but between incorrect states (\(oldStateName) -> \(newStateName))")
        }
        return false
    }
}

fileprivate func caseName(of value: Any) -> String {
    let mirror = Mirror(reflecting: value)
    return String(describing: mirror.children.first?.label ?? "\(value)")
}
