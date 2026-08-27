//
//  Created on 19/08/2026 by Max Kupetskyi.
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

import Foundation

protocol ThemeAssetCaching: AnyObject, Sendable {
    func removeAll()
}

/// Every cache Theme has made, so they can all be emptied at once.
///
/// `AppTheme.useVPNBrand()` empties them, because ProtonCore picks different assets per brand and
/// anything read before the brand was set came from the wrong one.
enum ThemeAssetCaches {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var caches: [any ThemeAssetCaching] = []

    static func register(_ cache: any ThemeAssetCaching) {
        lock.lock()
        defer { lock.unlock() }
        caches.append(cache)
    }

    /// Throws away every cached icon and color, so the next read goes back to the catalogue.
    static func removeAllValues() {
        lock.lock()
        let registered = caches
        lock.unlock()
        registered.forEach { $0.removeAll() }
    }
}

/// Remembers values that come from an asset catalogue so each one is read from disk only once.
///
/// Reading a named icon costs about 38 microseconds and reading a named color about 7, because both
/// go through CoreUI to the compiled catalogue and colors then run a color space conversion. The
/// theme asks for the same handful of entries on every view update, which added up to whole seconds
/// of work on the main thread,
///
/// The number of entries is bounded by the palette and the icon set, a few hundred at most, so
/// nothing is removed until someone empties the whole cache.
final class ThemeAssetCache<Key: Hashable, Value>: ThemeAssetCaching, @unchecked Sendable {
    private var values: [Key: Value] = [:]
    private let lock = NSLock()

    init() {
        ThemeAssetCaches.register(self)
    }

    /// The value for `key`, calling `resolve` only the first time each key is asked for.
    ///
    /// `resolve` runs outside the lock, so it may call AppKit or UIKit freely, and two threads asking
    /// for a missing key at the same time both resolve it. They produce equal values and the second
    /// one replaces the first, which costs one extra catalogue read and nothing else.
    func value(for key: Key, resolve: (Key) -> Value) -> Value {
        if let cached = read(key) {
            return cached
        }
        let resolved = resolve(key)
        write(resolved, for: key)
        return resolved
    }

    /// Empties the cache, so the next read of every key goes back to the catalogue.
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        values.removeAll()
    }

    private func read(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    private func write(_ value: Value, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }
}
