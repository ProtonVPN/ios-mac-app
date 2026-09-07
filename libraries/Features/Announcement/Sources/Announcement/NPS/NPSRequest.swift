//
//  Created on 2026-08-26 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
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

import CommonNetworking
import ProtonCoreNetworking

public struct NPSResponse: Codable {
    let code: Int // 1000 success
}

final class NPSRequest: Request {
    let useCase: UseCase

    enum UseCase: Equatable {
        case submit(score: Int, comment: String)
        case dismiss
    }

    init(useCase: UseCase) {
        self.useCase = useCase
    }

    var path: String {
        switch useCase {
        case .submit:
            "/vpn/v1/nps/submit"
        case .dismiss:
            "/vpn/v1/nps/dismiss"
        }
    }

    var parameters: [String: Any]? {
        switch useCase {
        case let .submit(score, comment):
            [
                "Score": score,
                "Comment": comment, // max 250 chars
            ]
        case .dismiss:
            [
                "Score": -1, // -1 value is when user is dismissing nps
            ]
        }
    }

    var method: HTTPMethod = .post

    var isAuth: Bool {
        true
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}

extension NPSRequest: CustomStringConvertible {
    var description: String {
        "\(type(of: self)) method: \(method), path: \(path), parameters: \(parameters ?? [:])"
    }
}

extension NPSRequest: MockResponse {
    var mockResponse: any Codable {
        NPSResponse(code: 1000)
    }
}
