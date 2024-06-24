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
import Dependencies
import CommonNetworking
import VPNShared
import Domain

public protocol SessionServiceFactory {
    func makeSessionService() -> SessionService
}

public protocol SessionService {
    var sessionCookie: HTTPCookie? { get }
    var accountHost: URL { get }

    func clientSessionId(forContext: AppContext) -> String

    func getSelector(clientId: String,
                     independent: Bool,
                     timeout: TimeInterval?) async throws -> String
}

extension SessionService {
    public func getSelector(clientId: String, independent: Bool) async throws -> String {
        try await getSelector(clientId: clientId, independent: independent, timeout: nil)
    }

    public func getPlanSession(mode: PlanSession) async -> URL {
        do {
            let selector = try await getSelector(clientId: "web-account-lite", independent: false)
            return mode.path(accountHost: self.accountHost, selector: selector)
        } catch {
            log.error("Failed to fork session, using default account url", category: .app, metadata: ["error": "\(error)"])
            return mode.path(accountHost: self.accountHost, selector: nil)
        }
    }

    public func getUpgradePlanSession(url: String) async -> String {
        do {
            let selector = try await getSelector(clientId: "web-account-lite", independent: false)
            return url + "#selector=" + selector
        } catch {
            log.error("Failed to fork session, using default account url", category: .app, metadata: ["error": "\(error)"])
            return url
        }
    }

    public func getExtensionSessionSelector(extensionContext: AppContext) async throws -> String {
        try await getSelector(clientId: clientSessionId(forContext: extensionContext), independent: false)
    }
}

public final class SessionServiceImplementation: SessionService {
    static let requestTimeout: TimeInterval = 3

    public typealias Factory = AppInfoFactory & NetworkingFactory
    private let appInfoFactory: AppInfoFactory
    private let doh: DoHVPN
    private let networking: Networking

    public var sessionCookie: HTTPCookie? {
        guard let apiUrl = URL(string: doh.defaultHost) else { return nil }

        return networking.apiService.getSession()?
            .sessionConfiguration.httpCookieStorage?
            .cookies(for: apiUrl)?
            .first(where: { $0.name == UserProperties.sessionIdCookieName })
    }

    public var accountHost: URL {
        URL(string: networking.apiService.doh.accountHost)!
    }

    public func clientSessionId(forContext context: AppContext) -> String {
        appInfoFactory.makeAppInfo(context: context).clientId
    }

    public init(factory: Factory) {
        @Dependency(\.dohConfiguration) var doh
        self.appInfoFactory = factory
        self.networking = factory.makeNetworking()
        self.doh = doh
    }

    // Exists for contexts that are allergic to factories
    public init(appInfoFactory: AppInfoFactory, networking: Networking, doh: DoHVPN) {
        self.networking = networking
        self.appInfoFactory = appInfoFactory
        self.doh = doh
    }

    public func getSelector(clientId: String,
                            independent: Bool,
                            timeout: TimeInterval? = nil) async throws -> String {
        let timeout = timeout ?? Self.requestTimeout
        let request = ForkSessionRequest(
            useCase: .getSelector(clientId: clientId, independent: independent),
            timeout: timeout
        )
        return try await withCheckedThrowingContinuation { continuation in
            networking.request(request) { (result: Result<ForkSessionResponse, Error>) in
                switch result {
                case let .success(data):
                    continuation.resume(with: .success(data.selector))
                case let .failure(error):
                    continuation.resume(with: .failure(error))
                }
            }
        }
    }
}
