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

struct CodeSignatureError: Error, CustomStringConvertible {
    let description: String
}

struct CodeSignatureComparitor {
    public static func codeSignatureMatches(auditToken: audit_token_t) throws -> Bool {
        return try codeSigningCertificatesForSelf() == codeSigningCertificates(for: auditToken)
    }

    // MARK: - Private
    private static func execute(secFunction: () -> OSStatus) throws {
        let status = secFunction()
        guard status == errSecSuccess else {
            let description = (SecCopyErrorMessageString(status, nil) as String?) ?? "Unknown code signing error"
            throw CodeSignatureError(description: "\(description) (\(status))")
        }
    }

    private static func codeSigningCertificatesForSelf() throws -> [SecCertificate] {
        let code = try secStaticCodeForSelf()
        return try codeSigningCertificates(for: code)
    }

    private static func codeSigningCertificates(for auditToken: audit_token_t) throws -> [SecCertificate] {
        let code = try secStaticCode(for: auditToken)
        return try codeSigningCertificates(for: code)
    }

    private static func secStaticCodeForSelf() throws -> SecStaticCode {
        var possibleSecCode: SecCode?
        try execute { SecCodeCopySelf([], &possibleSecCode) }

        guard let secCode = possibleSecCode else {
            throw CodeSignatureError(description: "secStaticCode for self failed with uninitialized secCode")
        }
        return try secStaticCode(for: secCode)
    }

    private static func secStaticCode(for auditToken: audit_token_t) throws -> SecStaticCode {
        let auditTokenData = withUnsafeBytes(of: auditToken) { bufPtr -> Data in
            guard let ptr = bufPtr.baseAddress else { return Data() }
            return Data(bytes: ptr, count: MemoryLayout<audit_token_t>.size)
        }

        var possibleSecCode: SecCode?
        try execute { SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributeAudit: auditTokenData as NSData] as CFDictionary, [], &possibleSecCode) }
        guard let secCode = possibleSecCode else {
            throw CodeSignatureError(description: "secStaticCode for audit token failed with uninitialized secCode")
        }
        return try secStaticCode(for: secCode)
    }

    private static func secStaticCode(for code: SecCode) throws -> SecStaticCode {
        var possibleSecStaticCode: SecStaticCode?
        try execute { SecCodeCopyStaticCode(code, [], &possibleSecStaticCode) }
        guard let secStaticCode = possibleSecStaticCode else {
            throw CodeSignatureError(description: "secStaticCode failed with uninitialized secStaticCode")
        }
        return secStaticCode
    }

    private static func codeSigningCertificates(for code: SecStaticCode) throws -> [SecCertificate] {
        guard let info = try secCodeInfo(for: code),
              let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate] else {
              throw CodeSignatureError(description: "codeSigningCertificates: no certificates found")
        }
        return certificates
    }

    private static func secCodeInfo(for code: SecStaticCode) throws -> [String: Any]? {
        try isValid(code)
        var possibleSecCodeInfoCFDict: CFDictionary?
        try execute { SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &possibleSecCodeInfoCFDict) }
        guard let secCodeInfoDict = possibleSecCodeInfoCFDict as? [String: Any] else {
            throw CodeSignatureError(description: "secCodeInfo failed with uninitialized secCodeInfoDict")
        }
        return secCodeInfoDict
    }

    private static func isValid(_ code: SecStaticCode) throws {
        // throws if invalid
        try execute { SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSDoNotValidateResources | kSecCSCheckNestedCode), nil) }
    }
}
