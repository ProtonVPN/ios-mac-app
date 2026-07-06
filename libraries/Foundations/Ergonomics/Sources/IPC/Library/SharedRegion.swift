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
import IPCSeqlockHelpers
import os
#if os(macOS)
    import IOSurface
#endif

// MARK: - RegionBacking

/// How a ``IPCNotifications/SharedRegion`` reaches its bytes. Used **only as a generic constraint**, never as `any
/// RegionBacking` — so calls through it are specialized per concrete backing (no witness-table dispatch). New backings
/// (a different shared-memory transport) just conform here.
public protocol RegionBacking: ~Copyable, Sendable {
    borrowing func withRawSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R
    borrowing func withMutableRawSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R
}

/// A single `mmap`'d file. Used on iOS and tvOS via the shared app group container, and by tests. Never moves once
/// mapped, so reads are lock-free. Noncopyable: it owns the mapping and `munmap`s it on `deinit`.
public struct FileBackedRegion: ~Copyable, Sendable {
    @_spi(Internals) public let mmapBuffer: MmapBuffer

    public init(fileURL: URL, size: Int) throws {
        self.mmapBuffer = try MmapBuffer(path: fileURL.path(), size: size)
    }
}

extension FileBackedRegion: RegionBacking {
    public borrowing func withRawSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try mmapBuffer.withRawSpan(body)
    }

    public borrowing func withMutableRawSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R {
        try mmapBuffer.withMutableRawSpan(body)
    }
}

#if os(macOS)
    /// An `IOSurface` the extension allocates and vends over XPC, since System Extensions can't reach the app group
    /// container. Noncopyable: it owns one retain of the surface.
    public struct IOSurfaceBackedRegion: ~Copyable, Sendable {
        @_spi(Internals) public let ioSurface: IOSurface

        public init(_ surface: IOSurfaceRef) {
            self.ioSurface = surface
        }

        /// Allocate an `IOSurface` large enough for `size` bytes. Returns `nil` if allocation fails.
        @inlinable
        public static func makeIOSurface(size: Int) -> IOSurfaceRef? {
            IOSurfaceCreate([
                kIOSurfaceWidth: size,
                kIOSurfaceHeight: 1,
                kIOSurfaceBytesPerElement: 1,
            ] as CFDictionary)
        }
    }

    extension IOSurfaceBackedRegion: RegionBacking {
        public borrowing func withRawSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
            let bufferPtr = UnsafeRawBufferPointer(
                start: IOSurfaceGetBaseAddress(ioSurface),
                count: IOSurfaceGetAllocSize(ioSurface)
            )
            return try body(bufferPtr.bytes)
        }

        public borrowing func withMutableRawSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R {
            var span = UnsafeMutableRawBufferPointer(
                start: IOSurfaceGetBaseAddress(ioSurface),
                count: IOSurfaceGetAllocSize(ioSurface)
            ).mutableBytes
            return try body(&span)
        }
    }
#endif

// MARK: - SharedRegion

public extension IPCNotifications {
    /// The shared home for one mapping. Owns a noncopyable ``RegionBacking`` (which is where single-ownership of the
    /// OS resource lives) and lets several ``IPCNotifications/RawChannel`` views — and concurrent reader tasks — share
    /// that one mapping. A reference type because sibling channels reading one mapping is inherently shared; it holds
    /// no seqlock of its own and, since the mapping never swaps in place, needs no lock.
    final class SharedRegion<Backing: RegionBacking & ~Copyable>: Sendable {
        @_spi(Internals) public let backing: Backing

        public init(_ backing: consuming Backing) {
            self.backing = backing
        }

        func withRawSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
            try backing.withRawSpan(body)
        }

        func withMutableRawSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R {
            try backing.withMutableRawSpan(body)
        }

        /// Vend a handle to the seqlock window whose header begins at `offset`.
        public func seqlockRegion(at offset: Int = 0, length: Int = Int(IPC_SHARED_REGION_SIZE)) -> SeqlockRegion<Backing> {
            SeqlockRegion(region: self, regionOffset: offset, length: length)
        }
    }
}

// MARK: - SeqlockRegion

/// A handle to one seqlock-protected window (`[IPCSharedHeader][Payload][padding]`) inside a shared mapping. Carries
/// *where* the window lives (which region, at what offset) but does not own the bytes
public struct SeqlockRegion<Backing: RegionBacking & ~Copyable>: ~Copyable, Sendable {
    let region: IPCNotifications.SharedRegion<Backing>
    let regionOffset: Int
    let length: Int

    fileprivate init(region: IPCNotifications.SharedRegion<Backing>, regionOffset: Int, length: Int) {
        self.region = region
        self.regionOffset = regionOffset
        self.length = length
    }
}
