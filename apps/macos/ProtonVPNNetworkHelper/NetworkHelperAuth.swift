//
//  NetworkHelperAuth.swift
//  ProtonVPN - Created on 27.06.19.
//
//  MIT License
//
//  Orignal work Copyright (c) 2018 Erik Berglund
//  Modified work Copyright (c) 2019 Proton Technologies AG
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

enum HelperAuthorizationError: Error {
    case message(String)
}

class NetworkHelperAuth {
    
    static let authorizationRights = [
        NetworkHelperAuthRight(command: #selector(NetworkHelperProtocol.enableFirewall(with:completion:)),
                               description: "NetworkHelper wants to run the command /sbin/pkctl",
                               ruleCustom: [kAuthorizationRightKeyClass: "user", kAuthorizationRightKeyGroup: "admin", kAuthorizationRightKeyVersion: 1]),
    ]
    
    static func authorizationRightsUpdateDatabase() throws {
        guard let authRef = try self.emptyAuthorizationRef() else {
            throw HelperAuthorizationError.message("Failed to get empty authorization ref")
        }
        
        for authorizationRight in self.authorizationRights {
            
            var osStatus = errAuthorizationSuccess
            var currentRule: CFDictionary?
            
            osStatus = AuthorizationRightGet(authorizationRight.name, &currentRule)
            if osStatus == errAuthorizationDenied || self.authorizationRuleUpdateRequired(currentRule, authorizationRight: authorizationRight) {
                osStatus = AuthorizationRightSet(authRef,
                                                 authorizationRight.name,
                                                 authorizationRight.rule(),
                                                 authorizationRight.description as CFString,
                                                 nil,
                                                 nil)
            }
            
            guard osStatus == errAuthorizationSuccess else {
                #if DEBUG
                print("AuthorizationRightSet or Get failed with error: \(String(describing: SecCopyErrorMessageString(osStatus, nil)))")
                #endif
                continue
            }
        }
    }
    
    static func authorizationRuleUpdateRequired(_ currentRuleCFDict: CFDictionary?, authorizationRight: NetworkHelperAuthRight) -> Bool {
        guard let currentRuleDict = currentRuleCFDict as? [String: Any] else {
            return true
        }
        let newRule = authorizationRight.rule()
        if CFGetTypeID(newRule) == CFStringGetTypeID() {
            if
                let currentRule = currentRuleDict[kAuthorizationRightKeyRule] as? [String],
                let newRule = authorizationRight.ruleConstant {
                return currentRule != [newRule]
                
            }
        } else if CFGetTypeID(newRule) == CFDictionaryGetTypeID() {
            if let currentVersion = currentRuleDict[kAuthorizationRightKeyVersion] as? Int,
                let newVersion = authorizationRight.ruleCustom?[kAuthorizationRightKeyVersion] as? Int {
                return currentVersion != newVersion
            }
        }
        return true
    }
    
    private static func executeAuthorizationFunction(_ authorizationFunction: () -> (OSStatus) ) throws {
        let osStatus = authorizationFunction()
        guard osStatus == errAuthorizationSuccess else {
            throw HelperAuthorizationError.message(String(describing: SecCopyErrorMessageString(osStatus, nil)))
        }
    }
    
    static func authorizationRef(_ rights: UnsafePointer<AuthorizationRights>?,
                                 _ environment: UnsafePointer<AuthorizationEnvironment>?,
                                 _ flags: AuthorizationFlags) throws -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        try executeAuthorizationFunction { AuthorizationCreate(rights, environment, flags, &authRef) }
        return authRef
    }
    
    static func emptyAuthorizationRef() throws -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        
        // Create an empty AuthorizationRef
        try executeAuthorizationFunction { AuthorizationCreate(nil, nil, [], &authRef) }
        return authRef
    }
}
