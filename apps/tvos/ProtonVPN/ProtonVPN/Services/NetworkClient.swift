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

    static let liveValue = NetworkClient(
        fetchSignInCode: {
            @Dependency(\.continuousClock) var clock
            try await clock.sleep(for: Self.fetchSignInCodeDelay)
            return SignInCode(selector: "40-char-random-hex-string", userCode: "1234ABCD")
        }, logout: {
            @Dependency(\.continuousClock) var clock
            try await clock.sleep(for: Self.logoutDelay)
        }, forkedSession: { selector in
            @Dependency(\.continuousClock) var clock
            print("poll API... \(Self.count)")
            try await clock.sleep(for: pollDelay)
            Self.count += 1
            if Self.count > 5 {
                Self.count = 1
                return .authenticated(.init(uid: "a", refreshToken: "b", accessToken: "c"))
            } else {
                throw "Failed to fork session"
            }
        }
    )
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
