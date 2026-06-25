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
import os
#if os(macOS)
    import IOSurface
#endif

public extension IPCNotifications {
    /// A single shared-memory region that backs one or more ``RawChannel`` views. Uses Spans to ensure safe accesses.
    final class SharedRegion: Sendable {
        /// How the region holds its backing. At the moment, IOSurface on macOS needs a lock for reads.
        private enum Backing: Sendable {
            case fixed(RegionBacking)
            #if os(macOS)
                case swappable(OSAllocatedUnfairLock<RegionBacking?>)
            #endif
        }

        private let backing: Backing

        /// A single `mmap`'d file. Used on iOS and tvOS via the shared app group container. Never changes, so reads
        /// are lock-free.
        public init(fileURL: URL, size: Int) throws {
            self.backing = try .fixed(RegionBacking(fileURL: fileURL, size: size))
        }

        #if os(macOS)
            /// An unattached, swappable region: reads return `nil` and writes no-op until an IOSurface is adopted.
            public init() {
                self.backing = .swappable(.init(initialState: nil))
            }

            /// A swappable region seeded with the IOSurface the extension allocates and vends to clients.
            public init(ioSurface: IOSurfaceRef) {
                self.backing = .swappable(.init(initialState: RegionBacking(ioSurface: ioSurface)))
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
        #endif

        /// Hot-swap a shared region while others may still be observing.
        public func adopt(_ other: SharedRegion) {
            #if os(macOS)
                guard case let .swappable(lock) = backing,
                      case let .swappable(otherLock) = other.backing
                else { return }
                lock.withLock { $0 = otherLock.withLock { $0 } }
            #endif
        }

        @discardableResult
        borrowing func withSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R? {
            switch backing {
            case let .fixed(backing):
                return try backing.withSpan(body)
            #if os(macOS)
                case let .swappable(lock):
                    guard let backing = lock.withLock({ $0 }) else { return nil }
                    return try backing.withSpan(body)
            #endif
            }
        }

        @discardableResult
        borrowing func withMutableSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R? {
            switch backing {
            case let .fixed(backing):
                return try backing.withMutableSpan(body)
            #if os(macOS)
                case let .swappable(lock):
                    guard let backing = lock.withLock({ $0 }) else { return nil }
                    return try backing.withMutableSpan(body)
            #endif
            }
        }
    }
}

/// Owns the shared-memory mapping that backs a region and vends bounded, non-escapable spans over it. Can be backed by
/// either a memory region created through `mmap` or IOSurface.
private final class RegionBacking: @unchecked Sendable {
    private enum Storage: ~Copyable {
        /// A file `mmap`. Used on iOS/tvOS, macOS may come later with App Extensions.
        case file(MmapBuffer)

        #if os(macOS)
            /// An `IOSurface` the extension allocates and vends over XPC in the case of System Extensions, since
            /// they can't access the app group container.
            case ioSurface(IOSurfaceRef)
        #endif
    }

    private let storage: Storage

    init(fileURL: URL, size: Int) throws {
        self.storage = try .file(MmapBuffer(path: fileURL.path(), size: size))
    }

    #if os(macOS)
        init(ioSurface: IOSurfaceRef) {
            self.storage = .ioSurface(ioSurface)
        }
    #endif

    borrowing func withSpan<R, E: Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        switch storage {
        case let .file(buffer):
            let span = UnsafeRawBufferPointer(start: buffer.baseAddress, count: buffer.totalSize).bytes
            return try body(span)
        #if os(macOS)
            case let .ioSurface(surface):
                let span = UnsafeRawBufferPointer(
                    start: IOSurfaceGetBaseAddress(surface),
                    count: IOSurfaceGetAllocSize(surface)
                ).bytes
                return try body(span)
        #endif
        }
    }

    borrowing func withMutableSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R {
        switch storage {
        case let .file(buffer):
            var span = UnsafeMutableRawBufferPointer(start: buffer.baseAddress, count: buffer.totalSize).mutableBytes
            return try body(&span)
        #if os(macOS)
            case let .ioSurface(surface):
                var span = UnsafeMutableRawBufferPointer(
                    start: IOSurfaceGetBaseAddress(surface),
                    count: IOSurfaceGetAllocSize(surface)
                ).mutableBytes
                return try body(&span)
        #endif
        }
    }
}
