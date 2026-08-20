//
//  Created on 25/03/2026.
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

import Darwin
import DarwinShims
import struct Foundation.Data
import struct Foundation.FileProtectionType
import struct Foundation.POSIXError

public enum MmapBufferError: Error {
    case openFailed(POSIXError)
    case mmapFailed(POSIXError)
    case fstatFailed(POSIXError)
    case truncateFailed(POSIXError)
    case renameFailed(POSIXError)
    case tooLargePayload
    case zeroSizePayload
    case unexpectedFileSize
}

public struct MmapBuffer: ~Copyable, Sendable {
    public let totalSize: Int
    public let inode: UInt64
    private let fd: FileDescriptor
    private nonisolated(unsafe) let pointer: UnsafeMutableRawPointer

    public init(path: String, size: Int = 65536) throws(MmapBufferError) {
        let rawFd = Darwin.open(path, O_RDWR | O_CREAT, 0o644)
        guard rawFd >= 0 else {
            throw .openFailed(POSIXError.shared)
        }
        try self.init(adoptingDescriptor: rawFd, size: size)
    }

    /// Private init that just takes a file descriptor, grows the file if needed, and mmap's it.
    private init(adoptingDescriptor rawFd: CInt, size: Int) throws(MmapBufferError) {
        let fd: FileDescriptor = .init(fd: rawFd)

        // Grow the file to the required size (no-op if already large enough).
        var info = stat()
        guard fstat(fd.fd, &info) == 0 else {
            throw .fstatFailed(.shared)
        }
        if info.st_size < off_t(size) {
            guard ftruncate(fd.fd, off_t(size)) == 0 else {
                throw .truncateFailed(.shared)
            }
        }

        let mmapRv = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd.fd, 0)
        guard mmapRv != MAP_FAILED, let mmapRv else {
            throw .mmapFailed(.shared)
        }

        self.pointer = mmapRv
        self.totalSize = size
        self.inode = UInt64(info.st_ino)
        self.fd = fd
    }

    /// Maps `size` bytes of an existing file read-only and for sharing with another process (`PROT_READ`, `MAP_SHARED`)
    /// for use with the ``ExtensionIPCClient``.
    public init(readingExistingPath path: String, size: Int) throws(MmapBufferError) {
        let rawFd = Darwin.open(path, O_RDONLY)
        guard rawFd >= 0 else {
            throw .openFailed(POSIXError.shared)
        }
        let fd = FileDescriptor(fd: rawFd)

        var info = stat()
        guard fstat(fd.fd, &info) == 0 else {
            throw .fstatFailed(.shared)
        }
        guard info.st_size >= off_t(size) else {
            throw .unexpectedFileSize
        }

        let mmapRv = mmap(nil, size, PROT_READ, MAP_SHARED, fd.fd, 0)
        guard mmapRv != MAP_FAILED, let mmapRv else {
            throw .mmapFailed(.shared)
        }

        self.pointer = mmapRv
        self.totalSize = size
        self.inode = UInt64(info.st_ino)
        self.fd = fd
    }

    /// Replaces `path` with a file of size `size` in the given protection class, and maps it read-write for use with
    /// the ``ExtensionIPCServer``.
    public init(replacingPath path: String, size: Int, protection: FileProtectionType) throws(MmapBufferError) {
        let stagingPath = path + ".new"
        // Clears any staging file a previous process might have had
        unlink(stagingPath)

        let rawFd = shim_open_dprotected(stagingPath, O_RDWR | O_CREAT | O_EXCL, protection.dataProtectionClass, 0o644)
        guard rawFd >= 0 else {
            throw .openFailed(POSIXError.shared)
        }
        let fd = FileDescriptor(fd: rawFd)

        guard ftruncate(fd.fd, off_t(size)) == 0 else {
            unlink(stagingPath)
            throw .truncateFailed(.shared)
        }
        guard rename(stagingPath, path) == 0 else {
            unlink(stagingPath)
            throw .renameFailed(.shared)
        }

        try self.init(adoptingDescriptor: fd.take(), size: size)
    }

    /// Maps an existing file locally and read-only (`MAP_PRIVATE`, `PROT_READ`), for decoding large binaries like the
    /// globe view.
    public init(readingPath path: String) throws(MmapBufferError) {
        let rawFd = Darwin.open(path, O_RDONLY)
        guard rawFd >= 0 else {
            throw .openFailed(POSIXError.shared)
        }
        let fd = FileDescriptor(fd: rawFd)

        var info = stat()
        guard fstat(fd.fd, &info) == 0 else {
            throw .fstatFailed(.shared)
        }
        let size = Int(info.st_size)
        guard size > 0 else {
            throw .zeroSizePayload
        }

        let mmapRv = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd.fd, 0)
        guard mmapRv != MAP_FAILED, let mmapRv else {
            throw .mmapFailed(.shared)
        }

        self.pointer = mmapRv
        self.totalSize = size
        self.inode = UInt64(info.st_ino)
        self.fd = fd
    }

    deinit {
        munmap(pointer, totalSize)
    }
}

public extension MmapBuffer {
    /// Scoped access to the whole mapped region as raw bytes. The pointer must not escape `body`; anything that has to
    /// outlive the scope should be expressed as offsets into the region and re-resolved against a later borrow.
    borrowing func withUnsafeBytes<R, E: Swift.Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        try body(UnsafeRawBufferPointer(start: pointer, count: totalSize))
    }

    /// `totalSize` rounded up to the page size. The kernel maps whole pages, so the rounded tail is real, zero-filled
    /// memory; a consumer adopting the region wholesale (like a Metal no-copy buffer, which requires a page-multiple
    /// length) should use this as the region's length.
    var pageAlignedSize: Int {
        let page = Int(getpagesize())
        return (totalSize + page - 1) & ~(page - 1)
    }
}

public extension MmapBuffer {
    /// Retrieve the file path associated with this mmap'd region using `fcntl(F_GETPATH)`.
    /// Returns `nil` if the path cannot be determined (e.g., the file was deleted).
    var filePath: String? {
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(MAXPATHLEN)) { pathBuffer in
            let pathBufferPtr = pathBuffer.baseAddress!
            guard fcntl(fd.fd, F_GETPATH, pathBufferPtr) == 0 else {
                return nil
            }
            return String(cString: pathBufferPtr)
        }
    }
}

public extension MmapBuffer {
    borrowing func load<T>(fromByteOffset offset: Int = 0, as type: T.Type) -> T {
        pointer.load(fromByteOffset: offset, as: type)
    }

    borrowing func read(fromByteOffset offset: Int = 0, count: Int, noCopy: Bool = false) -> Data {
        assert(offset >= 0 && count >= 0 && offset + count <= totalSize, "MmapBuffer.read: out of bounds")
        let dataPtrStart = pointer.advanced(by: offset)
        if noCopy {
            return Data(bytesNoCopy: dataPtrStart, count: count, deallocator: .none)
        } else {
            return Data(bytes: dataPtrStart, count: count)
        }
    }
}

public extension MmapBuffer {
    borrowing func storeBytes<T>(of value: T, toByteOffset offset: Int = 0, as type: T.Type) {
        pointer.storeBytes(of: value, toByteOffset: offset, as: type)
    }

    borrowing func write(data: Data, toByteOffset: Int) throws(MmapBufferError) {
        let dataSize = data.count
        guard dataSize > 0 else {
            throw .zeroSizePayload
        }
        guard toByteOffset + dataSize <= totalSize else {
            throw .tooLargePayload
        }
        data.withUnsafeBytes { dataPtr in
            pointer.advanced(by: toByteOffset).copyMemory(from: dataPtr.baseAddress!, byteCount: dataSize)
        }
    }

    borrowing func withRawSpan<R, E: Swift.Error>(_ body: (RawSpan) throws(E) -> R) throws(E) -> R {
        let span = UnsafeRawBufferPointer(start: pointer, count: totalSize).bytes
        return try body(span)
    }

    borrowing func withSpan<R, E: Swift.Error>(_ body: (Span<UInt8>) throws(E) -> R) throws(E) -> R {
        let span = UnsafeBufferPointer<UInt8>(start: pointer.assumingMemoryBound(to: UInt8.self), count: totalSize).span
        return try body(span)
    }

    borrowing func withMutableRawSpan<R, E: Error>(_ body: (inout MutableRawSpan) throws(E) -> R) throws(E) -> R {
        var mutableSpan = UnsafeMutableRawBufferPointer(start: pointer, count: totalSize).mutableBytes
        return try body(&mutableSpan)
    }

    borrowing func withMutableSpan<R, E: Swift.Error>(_ body: (inout MutableSpan<UInt8>) throws(E) -> R) throws(E) -> R {
        var mutableSpan = UnsafeMutableBufferPointer<UInt8>(start: pointer.assumingMemoryBound(to: UInt8.self), count: totalSize).mutableSpan
        return try body(&mutableSpan)
    }
}

extension MmapBufferError: Equatable {}

private extension FileProtectionType {
    /// Maps directly to the value passed to the `open_dprotected_np` syscall, declared in DarwinShims.h.
    var dataProtectionClass: DataProtectionClass {
        switch self {
        case .complete: .classA
        case .completeUnlessOpen: .classB
        case .completeUntilFirstUserAuthentication: .classC
        default: .classD
        }
    }
}
