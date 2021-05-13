//
//  Response.swift
//  Pods
//
//  Created on 5/25/20.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.

// swiftlint:disable identifier_name todo

import Foundation

open class Response {
    required public init() {}

    public var code: Int = 1000
    public var errorMessage: String?
    var internetCode: Int? // only use when error happend.

    public var error: NSError?

    func CheckHttpStatus() -> Bool {
        return code == 200 || code == 1000
    }

    func CheckBodyStatus () -> Bool {
        return code == 1000
    }

    func ParseResponseError (_ response: [String: Any]) -> Bool {
        code = response["Code"] as? Int ?? 0
        errorMessage = response["Error"] as? String

        if code != 1000 && code != 1001 {
            self.error = NSError.protonMailError(code,
                                                 localizedDescription: errorMessage ?? "",
                                                 localizedFailureReason: nil,
                                                 localizedRecoverySuggestion: nil)
        }
        return code != 1000 && code != 1001
    }

    func ParseHttpError (_ error: NSError, response: [String: Any]? = nil) {// TODO::need refactor.
        self.code = 404
        if let detail = error.userInfo["com.alamofire.serialization.response.error.response"] as? HTTPURLResponse {
            self.code = detail.statusCode
        } else {
            internetCode = error.code
            self.code = internetCode ?? 0
        }
        self.errorMessage = error.localizedDescription
        self.error = error
    }

    open func ParseResponse (_ response: [String: Any]) -> Bool {
        return true
    }
}
