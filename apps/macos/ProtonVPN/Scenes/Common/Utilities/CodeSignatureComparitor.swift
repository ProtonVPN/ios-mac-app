//
//  CodeSignatureComparitor.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

enum CodeSignatureError: Error {
    case message(String)
}

struct CodeSignatureComparitor {
    
    public static func codeSignatureMatches(pid: pid_t) throws -> Bool {
        return try codeSigningCertificatesForSelf() == codeSigningCertificates(for: pid)
    }
    
    // MARK: - Private
    private static func execute(secFunction: () -> OSStatus) throws {
        let status = secFunction()
        guard status == errSecSuccess else {
            throw CodeSignatureError.message(String(describing: SecCopyErrorMessageString(status, nil)))
        }
    }
    
    private static func codeSigningCertificatesForSelf() throws -> [SecCertificate] {
        let code = try secStaticCode(for: nil)
        return try codeSigningCertificates(for: code)
    }
    
    private static func codeSigningCertificates(for pid: pid_t) throws -> [SecCertificate] {
        let code = try secStaticCode(for: pid)
        return try codeSigningCertificates(for: code)
    }
    
    private static func secStaticCode(for pid: pid_t?) throws -> SecStaticCode {
        var possibleSecCode: SecCode?
        if let pid = pid {
            try execute { SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &possibleSecCode) }
        } else { // get sec code for this process
            try execute { SecCodeCopySelf([], &possibleSecCode) }
        }
        guard let secCode = possibleSecCode else {
            throw CodeSignatureError.message("secStaticCode for pid failed with uninitialized secCode")
        }
        return try secStaticCode(for: secCode)
    }
    
    private static func secStaticCode(for code: SecCode) throws -> SecStaticCode {
        var possibleSecStaticCode: SecStaticCode?
        try execute { SecCodeCopyStaticCode(code, [], &possibleSecStaticCode) }
        guard let secStaticCode = possibleSecStaticCode else {
            throw CodeSignatureError.message("secStaticCode failed with uninitialized secStaticCode")
        }
        return secStaticCode
    }
    
    private static func codeSigningCertificates(for code: SecStaticCode) throws -> [SecCertificate] {
        guard let info = try secCodeInfo(for: code),
              let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate] else {
            throw CodeSignatureError.message("codeSigningCertificates no certificates found")
        }
        return certificates
    }
    
    private static func secCodeInfo(for code: SecStaticCode) throws -> [String: Any]? {
        try isValid(code)
        var possibleSecCodeInfoCFDict: CFDictionary?
        try execute { SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &possibleSecCodeInfoCFDict) }
        guard let secCodeInfoDict = possibleSecCodeInfoCFDict as? [String: Any] else {
            throw CodeSignatureError.message("secCodeInfo failed with uninitialized secCodeInfoDict")
        }
        return secCodeInfoDict
    }
    
    private static func isValid(_ code: SecStaticCode) throws {
        // throws if invalid
        try execute { SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSDoNotValidateResources | kSecCSCheckNestedCode), nil) }
    }
}
