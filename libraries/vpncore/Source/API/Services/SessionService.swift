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
public protocol SessionServiceFactory {
    func makeSessionService() -> SessionService
}

public protocol SessionService {
    var sessionCookie: HTTPCookie? { get }
    var accountHost: String { get }

    func clientSessionId(forContext: AppContext) -> String

    func getSelector(clientId: String,
                     independent: Bool,
                     timeout: TimeInterval?,
                     completion: @escaping (Result<String, Error>) -> Void)
}

extension SessionService {
    func getSelector(clientId: String,
                     independent: Bool,
                     completion: @escaping (Result<String, Error>) -> Void) {
        getSelector(clientId: clientId, independent: independent, timeout: nil, completion: completion)
    }

    public func getUpgradePlanSession(completion: @escaping (String) -> Void) {
        getSelector(clientId: "web-account-lite", independent: false) { result in
            switch result {
            case let .success(selector):
                completion("\(self.accountHost)/lite?action=subscribe-account&fullscreen=off&redirect=protonvpn://refresh#selector=\(selector)")
            case let .failure(error):
                log.error("Failed to fork session, using default account url", category: .app, metadata: ["error": "\(error)"])
                completion("\(self.accountHost)/dashboard")
            }
        }
    }

    public func getUpgradePlanSession(url: String, completion: @escaping (String) -> Void) {
        getSelector(clientId: "web-account-lite", independent: false) { result in
            switch result {
            case let .success(selector):
                completion("\(url)#selector=\(selector)")
            case let .failure(error):
                log.error("Failed to fork session, using default url", category: .app, metadata: ["error": "\(error)"])
                completion("\(url)")
            }
        }
    }

    public func getExtensionSessionSelector(extensionContext: AppContext, completion: @escaping ((Result<String, Error>) -> Void)) {
        getSelector(clientId: clientSessionId(forContext: extensionContext),
                    independent: false,
                    completion: completion)
    }
}

public final class SessionServiceImplementation: SessionService {
    static let requestTimeout: TimeInterval = 3

    public typealias Factory = AppInfoFactory & NetworkingFactory & DoHVPNFactory
    private let appInfoFactory: AppInfoFactory
    private let doh: DoHVPN
    private let networking: Networking

    public var sessionCookie: HTTPCookie? {
        guard let apiUrl = URL(string: doh.defaultHost) else { return nil }

        return HTTPCookieStorage.shared
            .cookies(for: apiUrl)?
            .first(where: { $0.name == UserProperties.sessionIdCookieName })
    }

    public var accountHost: String {
        networking.apiService.doh.accountHost
    }

    public func clientSessionId(forContext context: AppContext) -> String {
        appInfoFactory.makeAppInfo(context: context).clientId
    }

    public init(factory: Factory) {
        self.appInfoFactory = factory

        self.networking = factory.makeNetworking()
        self.doh = factory.makeDoHVPN()
    }

    // Exists for contexts that are allergic to factories
    public init(appInfoFactory: AppInfoFactory, networking: Networking, doh: DoHVPN) {
        self.networking = networking
        self.appInfoFactory = appInfoFactory
        self.doh = doh
    }

    public func getSelector(clientId: String,
                            independent: Bool,
                            timeout: TimeInterval? = nil,
                            completion: @escaping (Result<String, Error>) -> Void) {
        let timeout = timeout ?? Self.requestTimeout
        let request = ForkSessionRequest(clientId: clientId, independent: independent, timeout: timeout)
        networking.request(request) { (result: Result<ForkSessionResponse, Error>) in
             switch result {
             case let .success(data):
                 completion(.success(data.selector))
             case let .failure(error):
                 completion(.failure(error))
             }
        }
    }
}
