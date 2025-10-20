//
//  Created on 01/10/2025 by Adam Viaud.
//
//  Copyright (c) 2025 Proton AG
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

#if os(macOS) || os(iOS)
    import Darwin

    /// Non-copyable wrapper for a file descriptor that automatically closes on deinit.
    struct FileDescriptor: ~Copyable {
        let fd: CInt

        init(fd: CInt) {
            self.fd = fd
        }

        deinit {
            close(fd)
        }
    }

    extension FileDescriptor: Sendable {}

    extension FileDescriptor {
        /// Consumes the FileDescriptor and returns the raw file descriptor without closing it.
        consuming func take() -> CInt {
            let rawFd = fd
            discard self
            return rawFd
        }

        /// Duplicates the file descriptor.
        func dup() -> FileDescriptor {
            .init(fd: Darwin.dup(fd))
        }
    }
#endif
