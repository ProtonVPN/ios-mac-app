//
//  Created on 29.11.2021.
//
//  Copyright (c) 2021 Proton AG
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
import ProtonCoreAPIClient
import ProtonCoreNetworking
import VPNShared

public final class ReportsBugs: Request {
    public let bug: ReportBug
    private let authKeychain: AuthKeychainHandle

    public init( _ bug: ReportBug, authKeychain: AuthKeychainHandle) {
        self.bug = bug
        self.authKeychain = authKeychain
    }

    public var path: String {
        return "/core/v4/reports/bug"
    }

    public var method: HTTPMethod {
        return .post
    }

    public var parameters: [String: Any]? {
        return [
            "OS": bug.os,
            "OSVersion": bug.osVersion,
            "Client": bug.client,
            "ClientVersion": bug.clientVersion,
            "ClientType": String(bug.clientType),
            "Title": bug.title,
            "Description": bug.description,
            "Username": bug.username,
            "Email": bug.email,
            "Country": bug.country,
            "ISP": bug.ISP,
            "Plan": bug.plan
        ]
    }

    public var isAuth: Bool {
        authKeychain.username != nil
    }

    public var retryPolicy: ProtonRetryPolicy.RetryMode {
        .userInitiated
    }
}
