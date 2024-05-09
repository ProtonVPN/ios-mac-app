//
//  Created on 23/04/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Dependencies
import CommonNetworking

struct NetworkClient: Sendable {
    var fetchSignInCode: @Sendable () async throws -> SignInCode
    var forkedSession: @Sendable (_ selector: String) async throws -> SessionAuthResult
    private static var count: Int = 1
}

public enum SessionAuthResult: Equatable {
    case authenticated(SessionAuthResponse)

    /// When we receive code 422 (invalid selector), return this instead of throwing an error
    case invalidSelector

    static let mockSuccess: SessionAuthResult = .authenticated(.init(uid: "a", refreshToken: "b", accessToken: "c"))
}

extension NetworkClient: DependencyKey {

    static let testValue = NetworkClient {
        SignInCode(selector: "40-char-random-hex-string",
                   userCode: "1234ABCD")
    } forkedSession: { selector in
            .mockSuccess
    }

    static let forkedSessionFailureValue = NetworkClient {
        SignInCode(selector: "40-char-random-hex-string",
                   userCode: "1234ABCD")
    } logout: {
        throw "nope"
    } forkedSession: { selector in
        throw "nope"
    }

    static let failureValue = NetworkClient {
        throw "nope"
    } logout: {
        throw "nope"
    } forkedSession: { selector in
        throw "nope"
    }

    static let fetchSignInCodeDelay: Duration = .seconds(1)
    static let logoutDelay: Duration = .seconds(1)
    static let pollDelay: Duration = .seconds(0.1)

    static var liveValue: NetworkClient {
        @Dependency(\.networking) var networking
        return NetworkClient(
            fetchSignInCode: {
                let request = ForkSessionRequest(useCase: .getUserCode, timeout: 5.0)
                let response: ForkSessionUserCodeResponse = try await networking.perform(request: request)
                return SignInCode(selector: response.selector, userCode: response.userCode)
            }, forkedSession: { selector in
                let request = SessionAuthRequest(selector: selector)
                do {
                    let response: SessionAuthResponse = try await networking.perform(request: request)
                    return .authenticated(response)
                } catch {
                    if error.httpCode == HttpStatusCode.invalidRefreshToken.rawValue {
                        // The selector has not been authenticated by the parent session
                        // Treat this as a type of success
                        return .invalidSelector
                    }
                    throw error // Rethrow generic errors
                }
            }
        )
    }
}

struct SignInCode: Equatable {
    let selector: String
    let userCode: String
}

struct AuthCredentials: Equatable { // temporary, we'll use the real AuthCredentials
    let uID: String
    let accessToken: String
    let refreshToken: String

    static let emptyCredentials = AuthCredentials(uID: "",
                                                  accessToken: "",
                                                  refreshToken: "")
}
