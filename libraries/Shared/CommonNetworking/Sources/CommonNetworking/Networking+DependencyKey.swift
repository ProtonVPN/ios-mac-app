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

import Dependencies
import Ergonomics
import Foundation
import IssueReporting
import NEHelper
import ProtonCoreAuthentication
import ProtonCoreDataModel
import ProtonCoreNetworking
import ProtonCoreServices
import VPNAppCore

public protocol VPNNetworking {
    var userTier: Int { get async throws }
    var userDisplayName: String? { get async throws }
    var sessionCookie: HTTPCookie? { get }
    var apiService: APIService { get } // APIService required by Payments

    func acquireSessionIfNeeded() async throws -> SessionAcquiringResult
    func setSession(_ session: Session)

    // Async/await methods
    func perform<T: Decodable>(request: Request) async throws -> T
    func perform<T: Codable>(request route: Request, files: [String: URL]) async throws -> T
    func perform(request route: Request) async throws -> JSONDictionary

    // Completion handler methods
    func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void)
    func request(_ route: ConditionalRequest, completion: @escaping (_ result: Result<IfModifiedSinceResponse<JSONDictionary>, Error>) -> Void)
    func request<T: Codable>(_ route: Request, completion: @escaping (_ result: Result<T, Error>) -> Void)
    func request(_ route: URLRequest, completion: @escaping (_ result: Result<String, Error>) -> Void)
    func request<T: Codable>(_ route: Request, files: [String: URL], completion: @escaping (_ result: Result<T, Error>) -> Void)
}

public struct CoreNetworkingWrapper: VPNNetworking {
    let wrapped: Networking

    public init(wrapped: Networking) {
        self.wrapped = wrapped
    }

    public var sessionCookie: HTTPCookie? {
        @Dependency(\.dohConfiguration) var doh
        guard let apiUrl = URL(string: doh.defaultHost) else { return nil }

        return wrapped.apiService.getSession()?
            .sessionConfiguration.httpCookieStorage?
            .cookies(for: apiUrl)?
            .first(where: { $0.name == CommonNetworking.Constants.sessionIDCookieName })
    }

    public var apiService: APIService {
        wrapped.apiService
    }

    public func acquireSessionIfNeeded() async throws -> SessionAcquiringResult {
        try await withCheckedThrowingContinuation { continuation in
            wrapped.apiService.acquireSessionIfNeeded(completion: continuation.resume(with:))
        }
    }

    public var userDisplayName: String? {
        get async throws {
            let user = try await withCheckedThrowingContinuation { continuation in
                Authenticator(api: wrapped.apiService).getUserInfo(completion: continuation.resume(with:))
            }
            return user.displayName
        }
    }

    // TODO: Hopefully when we start supporting free users we can ignore the MaxTier so this code would go away
    public var userTier: Int {
        get async throws {
            let json = try await wrapped.perform(request: VPNClientCredentialsRequest())
            guard let vpn: [String: Any] = try json[throwing: "VPN"],
                  let maxTier: Int = try vpn[throwing: "MaxTier"] else {
                return 0
            }
            return maxTier
        }
    }

    public func setSession(_ session: Session) {
        wrapped.apiService.setSessionUID(uid: session.uid)
    }

    public func perform<T: Decodable>(request: Request) async throws -> T {
        try await wrapped.perform(request: request)
    }

    public func perform<T: Codable>(request route: any Request, files: [String: URL]) async throws -> T {
        try await wrapped.perform(request: route, files: files)
    }

    public func perform(request route: any Request) async throws -> JSONDictionary {
        try await ((wrapped.apiService.perform(request: route)) as (URLSessionDataTask?, JSONDictionary)).1
    }

    public func request(_ route: any Request, completion: @escaping (Result<JSONDictionary, any Error>) -> Void) {
        wrapped.request(route, completion: completion)
    }

    public func request(
        _ route: any ConditionalRequest,
        completion: @escaping (Result<IfModifiedSinceResponse<JSONDictionary>, any Error>) -> Void
    ) {
        wrapped.request(route, completion: completion)
    }

    public func request<T: Codable>(
        _ route: any Request,
        completion: @escaping (Result<T, any Error>) -> Void
    ) {
        wrapped.request(route, completion: completion)
    }

    public func request(
        _ route: URLRequest,
        completion: @escaping (Result<String, any Error>) -> Void
    ) {
        wrapped.request(route, completion: completion)
    }

    public func request<T: Codable>(
        _ route: any Request,
        files: [String: URL],
        completion: @escaping (Result<T, any Error>) -> Void
    ) {
        wrapped.request(route, files: files, completion: completion)
    }
}

/// When using this dependency, make sure `liveValue` owns the only `CoreNetworking` instance.
public enum VPNNetworkingKey: TestDependencyKey {
    #if DEBUG
        public static let testValue: VPNNetworking = VPNNetworkingMock()
    #else
        public static let testValue: VPNNetworking = {
            fatalError("\(Self.self) must have a implementation")
        }()
    #endif
}

public extension DependencyValues {
    var networking: VPNNetworking {
        get { self[VPNNetworkingKey.self] }
        set { self[VPNNetworkingKey.self] = newValue }
    }
}

#if DEBUG
    struct VPNNetworkingMock: VPNNetworking {
        var userTierResult: Result<Int, Error>

        init(userTierResult: Result<Int, Error> = .failure("" as GenericError)) {
            self.userTierResult = userTierResult
        }

        func acquireSessionIfNeeded() async throws -> ProtonCoreServices.SessionAcquiringResult {
            throw "" as GenericError
        }

        var userTier: Int {
            get async throws {
                try userTierResult.get()
            }
        }

        var userDisplayName: String? {
            get async throws {
                throw "" as GenericError
            }
        }

        func setSession(_: Session) {}

        func perform<T>(request _: any ProtonCoreNetworking.Request) async throws -> T where T: Decodable {
            throw "" as GenericError
        }

        func perform<T>(request _: any Request, files _: [String: URL]) async throws -> T where T: Codable {
            throw "" as GenericError
        }

        var sessionCookie: HTTPCookie? {
            nil
        }

        var apiService: APIService {
            fatalError("Not implemented")
        }

        func perform(request _: any Request) async throws -> JSONDictionary {
            throw "" as GenericError
        }

        func request(_: any Request, completion _: @escaping (Result<JSONDictionary, any Error>) -> Void) {}

        func request(
            _: any ConditionalRequest,
            completion _: @escaping (Result<IfModifiedSinceResponse<JSONDictionary>, any Error>) -> Void
        ) {}

        func request<T: Codable>(
            _: any Request,
            completion _: @escaping (Result<T, any Error>) -> Void
        ) {}

        func request(
            _: URLRequest,
            completion _: @escaping (Result<String, any Error>) -> Void
        ) {}

        func request<T: Codable>(
            _: any Request,
            files _: [String: URL],
            completion _: @escaping (Result<T, any Error>) -> Void
        ) {}
    }
#endif
