//
//  Created on 14.08.2025 by John Biggs.
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

import Foundation

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(IOKit)
    import CryptoKit
    import IOKit

    // Taken from https://developer.apple.com/documentation/appstorereceipts/validating_receipts_on_the_device
    fileprivate func ioService(named name: String, wantBuiltIn: Bool) -> io_service_t? {
        let default_port = kIOMainPortDefault
        var iterator = io_iterator_t()
        defer {
            if iterator != IO_OBJECT_NULL {
                IOObjectRelease(iterator)
            }
        }

        guard let matchingDict = IOBSDNameMatching(default_port, 0, name),
              IOServiceGetMatchingServices(
                  default_port,
                  matchingDict as CFDictionary,
                  &iterator
              ) == KERN_SUCCESS,
              iterator != IO_OBJECT_NULL
        else {
            return nil
        }

        var candidate = IOIteratorNext(iterator)
        while candidate != IO_OBJECT_NULL {
            if let cftype = IORegistryEntryCreateCFProperty(
                candidate,
                "IOBuiltin" as CFString,
                kCFAllocatorDefault,
                0
            ) {
                let isBuiltIn = cftype.takeRetainedValue() as! CFBoolean
                if wantBuiltIn == CFBooleanGetValue(isBuiltIn) {
                    return candidate
                }
            }

            IOObjectRelease(candidate)
            candidate = IOIteratorNext(iterator)
        }

        return nil
    }
#endif

/// Get a sysctl with a string value.
/// - Note: *Only* works for String sysctls.
private func sysctl(byName name: String) -> String? {
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
    if ret < 0, errno == ENOMEM {
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

extension LogContent {
    #if canImport(IOKit)
        // Generate a UUID based on the MAC address of the device.
        fileprivate static var macDeviceIdentifier: UUID? {
            guard let service = ioService(named: "en0", wantBuiltIn: true)
                ?? ioService(named: "en1", wantBuiltIn: true)
                ?? ioService(named: "en0", wantBuiltIn: false)
            else { return nil }
            defer { IOObjectRelease(service) }

            guard let cfType = IORegistryEntrySearchCFProperty(
                service,
                kIOServicePlane,
                "IOMACAddress" as CFString,
                kCFAllocatorDefault,
                IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
            ), CFGetTypeID(cfType) == CFDataGetTypeID() else {
                return nil
            }

            let data = (cfType as! CFData) as Data
            var bytes = Data(SHA256.hash(data: data).prefix(16))
            bytes[6] = (bytes[6] & 0x0F) | 0x50
            bytes[8] = (bytes[8] & 0x3F) | 0x80

            return bytes.withUnsafeBytes { unsafeBytes in
                unsafeBytes.bindMemory(to: uuid_t.self).baseAddress.map { uuidPointer in
                    UUID(uuid: uuidPointer.pointee)
                }
            }
        }
    #endif

    fileprivate static var deviceIdentifier: String {
        #if canImport(UIKit)
            if let idfv = UIDevice.current.identifierForVendor {
                return idfv.uuidString
            }
        #endif

        #if canImport(IOKit)
            if let macAddress = macDeviceIdentifier {
                return macAddress.uuidString
            }
        #endif

        return ""
    }

    fileprivate static var platformName: String {
        #if os(iOS)
            return "iOS"
        #elseif os(macOS)
            return "macOS"
        #elseif os(watchOS)
            return "watchOS"
        #elseif os(tvOS)
            return "tvOS"
        #else
            return "unknown"
        #endif
    }

    fileprivate static var osVersionString: String {
        let processInfo = ProcessInfo.processInfo
        let os = processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }

    public static var modelName: String {
        #if os(macOS)
            // macOS devices have their official model name in the hw.model sysctl.
            // Other platforms use their codename here, so we use the method below instead.
            if let name = sysctl(byName: "hw.model") {
                return name
            }
        #endif

        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }

    // To be included at the top of every log file.
    public static var debugInfoString: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? ""
        let version = info?["CFBundleVersion"] as? String ?? ""
        let product = info?["CFBundleName"] as? String ?? ""

        return "pf=\(platformName); os=\(osVersionString); hw=\(modelName); pd=\(product); vn=\(shortVersion) (\(version)); id=\(deviceIdentifier)"
    }
}
