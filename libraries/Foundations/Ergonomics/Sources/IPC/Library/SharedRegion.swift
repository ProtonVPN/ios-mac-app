//
//  Created on 23/06/2026.
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

import Ergonomics
import Foundation
#if os(macOS)
    import IOSurface
#endif

public extension IPCNotifications {
    /// A single shared-memory region that backs one or more ``RawChannel`` views.
    /// Owns the mapping for its lifetime. On iOS and tvOS, this is a file `mmap` in the app group container, whereas
    /// the macOS extension must vend its shared memory region over NSXPC using an IOSurface.
    ///
    /// Since passing many of these files around is inconvenient, the ``RawChannel``s each have a view into a different
    /// offset of the shared region.
    final class SharedRegion: Sendable {
        private let backing: any SharedRegionBacking

        /// File-backed: a single `mmap`'d file. Used on iOS and tvOS via the shared app group container.
        public init(fileURL: URL, size: Int) throws {
            self.backing = try FileRegionBacking(fileURL: fileURL, size: size)
        }

        #if os(macOS)
            /// Create a shared region with an IOSurface, initially allocated by the extension, and vended to clients.
            public init(ioSurface: IOSurfaceRef) {
                self.backing = IOSurfaceRegionBacking(surface: ioSurface)
            }

            /// Allocate an `IOSurface` large enough for `size` bytes. Returns `nil` if allocation fails.
            public static func makeIOSurface(size: Int) -> IOSurfaceRef? {
                IOSurfaceCreate([
                    kIOSurfaceWidth: size,
                    kIOSurfaceHeight: 1,
                    kIOSurfaceBytesPerElement: 1,
                ] as CFDictionary)
            }
        #endif

        func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawPointer) throws -> R) rethrows -> R {
            try body(backing.baseAddress)
        }
    }
}

/// For now points to either an IOSurface or a file-backed `mmap`. All it really exposes is a pointer to a shared
/// region of memory.
private protocol SharedRegionBacking: Sendable {
    var baseAddress: UnsafeMutableRawPointer { get }
}

/// `mmap`'d file backing. `@unchecked` because it caches a raw pointer into memory it keeps mapped for its lifetime.
private final class FileRegionBacking: SharedRegionBacking, @unchecked Sendable {
    private let buffer: MmapBuffer
    let baseAddress: UnsafeMutableRawPointer

    init(fileURL: URL, size: Int) throws {
        let buffer = try MmapBuffer(path: fileURL.path(), size: size)
        self.baseAddress = buffer.baseAddress
        self.buffer = buffer
    }
}

#if os(macOS)
    /// `IOSurface` backing. Retains the surface (keeping its memory wired) and caches its stable base address.
    private final class IOSurfaceRegionBacking: SharedRegionBacking, @unchecked Sendable {
        private let surface: IOSurfaceRef
        let baseAddress: UnsafeMutableRawPointer

        init(surface: IOSurfaceRef) {
            self.surface = surface
            self.baseAddress = IOSurfaceGetBaseAddress(surface)
        }
    }
#endif
