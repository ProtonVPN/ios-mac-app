//
//  Created on 18/08/2026.
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

import AsyncAlgorithms
import ConcurrencyExtras

public extension AsyncStream where Element: Sendable {
    /// Merges streams into one that emits whenever any source does, treating every source equally. Take care not to use
    /// `flatMapLatest` here since this starves certain sources if task priorities don't match.
    static func merging(_ streams: [AsyncStream<Element>]) -> AsyncStream<Element> {
        guard var merged = streams.first else { return .finished }
        for stream in streams.dropFirst() {
            merged = UncheckedSendable(merge(merged, stream)).eraseToStream()
        }
        return merged
    }
}
