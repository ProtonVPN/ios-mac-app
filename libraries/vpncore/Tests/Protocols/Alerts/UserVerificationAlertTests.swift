//
//  UserVerificationAlerttests.swift
//  vpncore - Created on 2021-04-02.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import XCTest

class UserVerificationAlertTests: XCTestCase {
    
    #if os(iOS)
    func testUserVerificationAlertOnIosDoesntHaveMessage() throws {
        let alert = UserVerificationAlert(verificationMethods: VerificationMethods(availableTokenTypes: [.captcha], captchaToken: nil), error: ErrorWithMessage("Error mesage text"), success: {_ in }, failure: { _ in })
        
        XCTAssert(alert.message == nil)
    }
    #endif
    
    #if os(macOS)
    func testUserVerificationAlertOnMacOSHasMessage() throws {
        let alert = UserVerificationAlert(verificationMethods: VerificationMethods(availableTokenTypes: [.captcha], captchaToken: nil), error: ErrorWithMessage("Error mesage text"), success: {_ in }, failure: { _ in })
        
        XCTAssert(alert.message != nil)
    }
    #endif

    class ErrorWithMessage: Error {
        
        public let localizedDescription: String
        
        public init(_ localizedDescription: String){
            self.localizedDescription = localizedDescription
        }
    }
        
}
