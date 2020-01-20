//
//  NetworkHelperConstants.swift
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

let kAuthorizationRightKeyClass     = "class"
let kAuthorizationRightKeyGroup     = "group"
let kAuthorizationRightKeyRule      = "rule"
let kAuthorizationRightKeyTimeout   = "timeout"
let kAuthorizationRightKeyVersion   = "version"

let kAuthorizationFailedExitCode    = NSNumber(value: 503340)

struct NetworkHelperConstants {
    
    static let machServiceName = "ch.protonvpn.ProtonVPNNetworkHelper"
}
