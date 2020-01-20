//
//  NetworkHelperAuthRight.swift
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

struct NetworkHelperAuthRight {
    
    let command: Selector
    let name: String
    let description: String
    let ruleCustom: [String: Any]?
    let ruleConstant: String?
    
    init(command: Selector, name: String? = nil, description: String, ruleCustom: [String: Any]? = nil, ruleConstant: String? = nil) {
        self.command = command
        self.name = name ?? NetworkHelperConstants.machServiceName + "." + command.description
        self.description = description
        self.ruleCustom = ruleCustom
        self.ruleConstant = ruleConstant
    }
    
    func rule() -> CFTypeRef {
        let rule: CFTypeRef
        if let ruleCustom = self.ruleCustom as CFDictionary? {
            rule = ruleCustom
        } else if let ruleConstant = self.ruleConstant as CFString? {
            rule = ruleConstant
        } else {
            rule = kAuthorizationRuleAuthenticateAsAdmin as CFString
        }
        
        return rule
    }
}
