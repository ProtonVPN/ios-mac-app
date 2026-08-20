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

public protocol RegionBacking: ~Copyable, Sendable {
    /// A stable identity for the mapping (file inode, surface id), announced by the writer, and compared by the reader
    /// for detecting if the backing region has changed.
    var regionID: UInt64 { get }

    borrowing func withRawSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R
}

/// A backing whose bytes can also be written, for use with ``ExtensionIPCServer``.
public protocol MutableRegionBacking: RegionBacking, ~Copyable {
    borrowing func withMutableRawSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R
}

/// A single `mmap`'d file, mapped read-write.
public struct FileBackedRegion: ~Copyable, Sendable {
    @_spi(Internals) public let mmapBuffer: MmapBuffer

    public init(fileURL: URL, size: Int) throws {
        self.mmapBuffer = try MmapBuffer(path: fileURL.path(), size: size)
    }

    /// Replaces whatever is at `fileURL` with a fresh file in the given protection class and maps it read-write.
    public init(creating fileURL: URL, size: Int, protection: FileProtectionType) throws(MmapBufferError) {
        self.mmapBuffer = try MmapBuffer(replacingPath: fileURL.path(), size: size, protection: protection)
    }
}

extension FileBackedRegion: MutableRegionBacking {
    public var regionID: UInt64 {
        mmapBuffer.inode
    }

    public borrowing func withRawSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try mmapBuffer.withRawSpan(body)
    }

    public borrowing func withMutableRawSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R {
        try mmapBuffer.withMutableRawSpan(body)
    }
}

/// The reading side of a ``FileBackedRegion``, mapped read-only and shared.
public struct ReadOnlyFileBackedRegion: ~Copyable, Sendable {
    @_spi(Internals) public let mmapBuffer: MmapBuffer

    /// Maps the existing file at `fileURL` without creating or growing it.
    public init(opening fileURL: URL, size: Int) throws(MmapBufferError) {
        self.mmapBuffer = try MmapBuffer(readingExistingPath: fileURL.path(), size: size)
    }
}

extension ReadOnlyFileBackedRegion: RegionBacking {
    /// The mapped file's inode, compared against what the writer announced.
    public var regionID: UInt64 {
        mmapBuffer.inode
    }

    public borrowing func withRawSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        try mmapBuffer.withRawSpan(body)
    }
}

#if os(macOS)
    /// An `IOSurface` the extension allocates and vends over XPC, since System Extensions can't reach the app group
    /// container. Noncopyable: it owns one retain of the surface.
    public struct IOSurfaceBackedRegion: ~Copyable, Sendable {
        @_spi(Internals) public let ioSurface: IOSurface

        /// The kernel's identifier for this surface
        public var id: IOSurfaceID {
            IOSurfaceGetID(ioSurface)
        }

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

    extension IOSurfaceBackedRegion: MutableRegionBacking {
        public var regionID: UInt64 {
            UInt64(id)
        }

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

        /// Provide a handle to the seqlock window whose header begins at `offset`.
        public func seqlockRegion(at offset: Int = 0, length: Int = Int(IPC_SHARED_REGION_SIZE)) -> SeqlockRegion<Backing> {
            SeqlockRegion(region: self, regionOffset: offset, length: length)
        }
    }
}

extension IPCNotifications.SharedRegion where Backing: MutableRegionBacking & ~Copyable {
    func withMutableRawSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R {
        try backing.withMutableRawSpan(body)
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
