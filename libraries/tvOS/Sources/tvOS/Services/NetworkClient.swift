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
import CasePaths
import Dependencies
import CommonNetworking

struct NetworkClient: Sendable {
    var fetchSignInCode: @Sendable () async throws -> SignInCode
    var forkedSession: @Sendable (_ selector: String) async throws -> SessionAuthResult
}

@CasePathable
public enum SessionAuthResult: Equatable {

    case authenticated(SessionAuthResponse)

    /// When we receive code 422 (invalid selector), return this instead of throwing an error
    case invalidSelector
}

extension NetworkClient: DependencyKey {
    static var liveValue: NetworkClient {
        @Dependency(\.networking) var networking
        return NetworkClient(
            fetchSignInCode: {
                let request = ForkSessionRequest(useCase: .getUserCode)
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

extension DependencyValues {
    var networkClient: NetworkClient {
      get { self[NetworkClient.self] }
      set { self[NetworkClient.self] = newValue }
    }
}

struct SignInCode: Equatable {
    let selector: String
    private let userCode: String

    init(selector: String, userCode: String) {
        self.selector = selector
        self.userCode = userCode
    }
}

extension SignInCode {
    /// We want to present the 8 character code with a space in the middle in the UI
    /// We get the string from API without a space
    var userFacingUserCode: String {
        guard userCode.count == 8 else {
            return userCode
        }
        var userCode = userCode
        userCode.insert(" ", at: .init(utf16Offset: 4, in: userCode))
        return userCode
    }
}
