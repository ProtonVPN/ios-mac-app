//
//  Created on 02.05.2022.
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
import ProtonCoreAPIClient
import ProtonCoreNetworking

public struct ForkSessionRequest: Request {
    let useCase: UseCase
    let timeout: TimeInterval

    public enum UseCase {
        case getSelector(clientId: String, independent: Bool)
        case getUserCode
    }

    public init(useCase: UseCase, timeout: TimeInterval) {
        self.useCase = useCase
        self.timeout = timeout
    }

    public var nonDefaultTimeout: TimeInterval {
        return timeout
    }

    public var path: String {
        return "/auth/v4/sessions/forks"
    }

    public var method: HTTPMethod {
        switch useCase {
        case .getSelector:
            return .post
        case .getUserCode:
            return .get
        }
    }

    public var parameters: [String: Any]? {
        switch useCase {
        case .getSelector(let clientId, let independent):
            return [
                "ChildClientID": clientId,
                "Independent": independent ? 1 : 0,
            ]
        case .getUserCode:
            return nil
        }
    }

    #if canImport(Alamofire)
    public var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
    #endif
}
