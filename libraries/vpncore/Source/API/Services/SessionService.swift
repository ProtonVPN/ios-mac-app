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

    func getUpgradePlanSession(completion: @escaping (String) -> Void)
    func getExtensionSessionSelector(extensionContext: AppContext, completion: @escaping (Result<String, Error>) -> Void)
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

    public func getUpgradePlanSession(completion: @escaping (String) -> Void) {
        let accountHost = networking.apiService.doh.accountHost
        #if os(macOS)
        let platform = "macOS"
        #else
        let platform = "iOS"
        #endif

        getSelector(clientId: "web-account-lite", independent: false) { result in
            switch result {
            case let .success(selector):
                completion("\(accountHost)/lite?action=subscribe-account&client=\(platform)#selector=\(selector)")
            case let .failure(error):
                log.error("Failed to fork session, using default account url", category: .app, metadata: ["error": "\(error)"])
                completion("\(accountHost)/dashboard")
            }
        }
    }

    public func getExtensionSessionSelector(extensionContext: AppContext, completion: @escaping ((Result<String, Error>) -> Void)) {
        getSelector(clientId: appInfoFactory.makeAppInfo(context: extensionContext).clientId,
                    independent: false,
                    completion: completion)
    }

    private func getSelector(clientId: String,
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
