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
import Ergonomics
import IPCDefinitions
import IPCErgonomics
import os

#if os(macOS)
    typealias ReaderStore = TunnelDataStore<ReaderRole, IOSurfaceBackedRegion>
#else
    typealias ReaderStore = TunnelDataStore<ReaderRole, ReadOnlyFileBackedRegion>
#endif

/// The reader side's mutable state, which keeps track of the store for the region plus the change ticks.
final class AttachedRegion: Sendable {
    private let current = OSAllocatedUnfairLock<ReaderStore?>(initialState: nil)
    private let swaps = Broadcast<Void>()

    /// The store for the announced region, or `nil` if none has been observed.
    var store: ReaderStore? {
        current.withLock { $0 }
    }

    /// The identity of the mapped region, or `nil` when nothing is attached.
    var regionID: UInt64? {
        store?.regionID
    }

    /// Replaces the store when `stale` decides the current one no longer matches the announcement, and pings observers.
    @discardableResult
    func replace(when stale: (ReaderStore?) -> Bool, with make: () throws -> ReaderStore) rethrows -> Bool {
        guard current.withLock({ stale($0) }) else { return false }
        let fresh = try make()
        let installed = current.withLock { store -> Bool in
            guard stale(store) else { return false }
            store = fresh
            return true
        }
        if installed {
            swaps.send()
        }
        return installed
    }
}

extension AttachedRegion {
    /// A subscriber's "progress" through one channel.
    private struct Cursor: Sendable {
        private var regionID: UInt64?
        private var sequence = UInt64.max

        mutating func read<Payload>(
            in region: UInt64,
            _ channel: (_ since: UInt64) -> (value: Payload?, sequence: UInt64)?
        ) -> Payload? {
            if regionID != region {
                regionID = region
                sequence = .max
            }
            guard let (value, sequence) = channel(sequence) else { return nil }
            self.sequence = sequence
            return value
        }
    }

    /// One stream over one channel that survives the region being replaced underneath it.
    func stream<Payload: BitwiseCopyable & Sendable, T: Sendable>(
        reconcileOn extraSignals: AsyncStream<Void>...,
        read: @escaping @Sendable (ReaderStore, _ since: UInt64) -> (value: Payload?, sequence: UInt64)?,
        transform: @escaping @Sendable (Payload) -> T
    ) -> AsyncStream<T> {
        let ticks = AsyncStream.merging([swaps.subscribe(), IPCNotifications.ticks(.tunnelData)] + extraSignals)
        return UncheckedSendable(
            ticks
                .reductions(into: (cursor: Cursor(), value: T?.none)) { acc, _ in
                    acc.value = self.store.flatMap { store in
                        acc.cursor.read(in: store.regionID) { read(store, $0) }.map(transform)
                    }
                }
                .compactMap(\.value)
        ).eraseToStream()
    }
}
