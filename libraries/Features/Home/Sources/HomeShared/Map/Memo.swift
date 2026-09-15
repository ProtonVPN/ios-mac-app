//
//  Created on 03.08.2026 by John Biggs.
//
//  Copyright (c) 2026 Proton AG
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

/// A one-entry answer holder for a value that is asked for far more often than its input changes.
///
/// Keyed on the input rather than invalidated by hand, which is what separates it from a stored copy of derived state.
/// There is no second source to keep in agreement and nothing to remember to clear, because an answer is either for the
/// key being asked about or it is recomputed. The worst a stale entry can do is cost one extra computation.
///
/// One entry is enough for the map's uses: each has a single input at a time, and recomputing when that input changes
/// is exactly the work being kept off the per-frame path, not work being avoided altogether.
///
/// Carries no isolation of its own. Whoever holds one decides that, which for the globe is `GlobeRenderInputs`, held by
/// the view. A memo parked in a static would instead need a global actor to be safe, and would then push that
/// requirement onto pure functions that have no reason to want it.
struct Memo<Key: Equatable, Value> {
    private var entry: (key: Key, value: Value)?
    private let compute: (Key) -> Value

    init(_ compute: @escaping (Key) -> Value) {
        self.compute = compute
    }

    /// The value for `key`, recomputed only when it differs from the key this memo last answered for.
    mutating func callAsFunction(_ key: Key) -> Value {
        if let entry, entry.key == key {
            return entry.value
        }
        let value = compute(key)
        entry = (key, value)
        return value
    }
}
