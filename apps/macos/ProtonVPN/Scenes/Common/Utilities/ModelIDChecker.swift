//
//  Created on 2022-02-21.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import LegacyCommon

protocol ModelIdCheckerProtocol {
    var modelId: String? { get }
}

protocol ModelIdCheckerFactory {
    func makeModelIdChecker() -> ModelIdCheckerProtocol
}

extension ModelIdCheckerProtocol {
    var isT2Mac: Bool {
        guard let modelId = modelId else {
            return false
        }
        return ModelIdChecker.macT2ModelNames.contains(modelId)
    }
}

struct ModelIdChecker {
    /// All of the Mac models that use the T2 coprocessor chip.
    static let macT2ModelNames = [
        "iMac20,1",
        "iMacPro1,1",
        "MacPro7,1",
        "Macmini8,1",
        "MacBookAir8,1",
        "MacBookAir8,2",
        "MacBookAir9,1",
        "MacBookPro15,1",
        "MacBookPro15,2",
        "MacBookPro15,3",
        "MacBookPro15,4",
        "MacBookPro16,1",
        "MacBookPro16,2",
        "MacBookPro16,3",
        "MacBookPro16,4",
    ]
}

private extension ModelIdChecker {
    /// Get a sysctl with a string value.
    /// - Note: *Only* works for String sysctls.
    func sysctl(byName name: String) -> String? {
        let bufSize = 64

        var ctlBuf = UnsafeMutableRawPointer.allocate(byteCount: bufSize, alignment: 1)
        defer { ctlBuf.deallocate() }

        let sizePtr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer { sizePtr.deallocate() }

        sizePtr.pointee = bufSize

        let ret = sysctlbyname(name, ctlBuf, sizePtr, nil, 0)
        guard ret == 0 || errno == ENOMEM else {
            return nil
        }

        // sysctlbyname returns -1 and sets errno = ENOMEM if the buffer was too small.
        // Try again w/ size that the kernel told us to use, assuming it's not too big.
        if ret < 0 && errno == ENOMEM {
            errno = 0

            let newSize = sizePtr.pointee
            // Make sure we aren't being asked to allocate an unreasonable amount of memory
            guard newSize < 8192 else { return nil }

            ctlBuf.deallocate()
            ctlBuf = UnsafeMutableRawPointer.allocate(byteCount: newSize, alignment: 1)
            let ret = sysctlbyname(name, ctlBuf, sizePtr, nil, 0)

            guard ret == 0 else {
                return nil
            }
        }

        let boundPtr = ctlBuf.bindMemory(to: Int8.self, capacity: sizePtr.pointee)
        let stringLen = strnlen(boundPtr, sizePtr.pointee)
        let ptrData = Data(bytes: boundPtr, count: stringLen)
        return String(bytes: ptrData, encoding: .ascii)
    }
}

extension ModelIdChecker: ModelIdCheckerProtocol {
    var modelId: String? {
        return sysctl(byName: "hw.model")
    }
}
