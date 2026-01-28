//
//  Created on 07/01/2026 by adam.
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

#if canImport(Darwin)
    import Darwin
    import struct Foundation.POSIXError

    public enum FileDescriptorError: Swift.Error {
        case fcntlFailed(POSIXError)
    }

    extension FileDescriptor {
        var fdFlags: CInt {
            get throws(FileDescriptorError) {
                let res = fcntl(fd, F_GETFL, 0)
                guard res != -1 else {
                    throw .fcntlFailed(POSIXError.shared)
                }
                return res
            }
        }

        /// Returns whether the file descriptor is in non-blocking mode.
        var isNonBlocking: Bool {
            (try? fdFlags & O_NONBLOCK != 0) ?? false
        }

        /// Sets the socket to non-blocking or blocking mode.
        /// - Parameter nonBlocking: pass `true` to enable non-blocking mode.
        public func setNonBlocking(_ nonBlocking: Bool) throws(FileDescriptorError) {
            let fdFlags = try fdFlags
            let newFlags: CInt = nonBlocking ? (fdFlags | O_NONBLOCK) : (fdFlags & ~O_NONBLOCK)
            guard fcntl(fd, F_SETFL, newFlags) == 0 else {
                throw .fcntlFailed(POSIXError.shared)
            }
        }
    }
#endif
