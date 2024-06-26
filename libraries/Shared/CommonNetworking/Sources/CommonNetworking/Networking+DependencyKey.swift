//
//  Created on 01/05/2024.
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
import XCTestDynamicOverlay

import ProtonCoreServices
import ProtonCoreNetworking
import ProtonCoreAuthentication
import ProtonCoreDataModel

public protocol VPNNetworking {
    func acquireSessionIfNeeded() async throws -> SessionAcquiringResult
    func set(session: Session)
    func perform<T: Decodable>(request: Request) async throws -> T
    var userTier: Int { get async throws }
    var userDisplayName: String? { get async throws }
    var sessionCookie: HTTPCookie? { get }
}

public struct CoreNetworkingWrapper: VPNNetworking {
    public var sessionCookie: HTTPCookie? {
        @Dependency(\.dohConfiguration) var doh
        guard let apiUrl = URL(string: doh.defaultHost) else { return nil }

        return wrapped.apiService.getSession()?
            .sessionConfiguration.httpCookieStorage?
            .cookies(for: apiUrl)?
            .first(where: { $0.name == CommonNetworking.Constants.sessionIDCookieName })
    }
    
    public func acquireSessionIfNeeded() async throws -> SessionAcquiringResult {
        try await withCheckedThrowingContinuation { continuation in
            wrapped.apiService.acquireSessionIfNeeded(completion: continuation.resume(with:))
        }
    }

    public var userDisplayName: String? {get async throws {
        let user = try await withCheckedThrowingContinuation { continuation in
            Authenticator(api: wrapped.apiService).getUserInfo(completion: continuation.resume(with:))
        }
        return user.displayName
    } }

    // TODO: Hopefully when we start supporting free users we can ignore the MaxTier so this code would go away
    public var userTier: Int { get async throws {
        let json = try await wrapped.perform(request: VPNClientCredentialsRequest())
        guard let vpn: [String: Any] = try json[throwing: "VPN"],
              let maxTier: Int = try vpn[throwing: "MaxTier"] else {
            return 0
        }
        return maxTier
    } }

    public func set(session: Session) {
        wrapped.apiService.setSessionUID(uid: session.uid)
    }
    
    let wrapped: Networking

    public func perform<T: Decodable>(request: Request) async throws -> T {
        try await wrapped.perform(request: request)
    }
}

/// If using this dependency, make sure `liveValue` owns the only `CoreNetworking` instance.
public enum VPNNetworkingKey: DependencyKey {
    public static var liveValue: VPNNetworking {
        #if TLS_PIN_DISABLE
        let pinAPIEndpoints = false
        #else
        let pinAPIEndpoints = true
        #endif

        let networking = CoreNetworking(
            delegate: Dependency(\.networkingDelegate).wrappedValue,
            appInfo: Dependency(\.appInfo).wrappedValue,
            authKeychain: Dependency(\.authKeychain).wrappedValue,
            unauthKeychain: Dependency(\.unauthKeychain).wrappedValue,
            pinApiEndpoints: pinAPIEndpoints
        )

        return CoreNetworkingWrapper(wrapped: networking)
    }
}

extension DependencyValues {
    public var networking: VPNNetworking {
        get { self[VPNNetworkingKey.self] }
        set { self[VPNNetworkingKey.self] = newValue }
    }
}

final class VPNClientCredentialsRequest: Request { // TODO: There's a duplicate in legacy common, but we don't want to import that beast
    var path: String {
        return "/vpn/v2"
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}

struct VPNNetworkingMock: VPNNetworking {

    func acquireSessionIfNeeded() async throws -> ProtonCoreServices.SessionAcquiringResult {
        throw ""
    }

    var userTier: Int { get async throws {
        throw ""
    } }

    var userDisplayName: String? { get async throws {
        throw ""
    } }

    func set(session: CommonNetworking.Session) {
        
    }

    func perform<T>(request: any ProtonCoreNetworking.Request) async throws -> T where T : Decodable {
        throw ""
    }

    var sessionCookie: HTTPCookie? {
        nil
    }
}
