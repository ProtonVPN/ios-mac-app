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
import struct Foundation.Data
import struct Foundation.POSIXError

public enum MmapBufferError: Error {
    case openFailed(POSIXError)
    case mmapFailed(POSIXError)
    case fstatFailed(POSIXError)
    case truncateFailed(POSIXError)
    case tooLargePayload
    case zeroSizePayload
}

public struct MmapBuffer: ~Copyable {
    public let totalSize: Int
    private let pointer: UnsafeMutableRawPointer

    public init(path: String, size: Int = 65536) throws(MmapBufferError) {
        let rawFd = Darwin.open(path, O_RDWR | O_CREAT, 0o644)
        let fd: FileDescriptor = .init(fd: rawFd)
        guard fd.fd >= 0 else {
            throw .openFailed(POSIXError.shared)
        }

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
    }

    deinit {
        munmap(pointer, totalSize)
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

    /// Grants scoped access to the raw mmap'd bytes. Do not let the pointer escape the closure.
    package borrowing func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawPointer) throws -> R) rethrows -> R {
        try body(pointer)
    }
}

extension MmapBufferError: Equatable {}
