//
//  Created on 20/06/2024.
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
import Domain
import Foundation
import IssueReporting
import PMLogger

public enum PlanSession {
    case upgrade
    case manageSubscription
    case promo2yPlan

    var queryItems: [URLQueryItem] {
        switch self {
        case .upgrade:
            [.actionQueryItem, .appQueryItem, .fullscreenQueryItem, .redirectQueryItem, .typeQueryItem]
        case .manageSubscription:
            [.actionQueryItem, .appQueryItem, .fullscreenQueryItem, .redirectQueryItem]
        case .promo2yPlan:
            [
                .actionQueryItem,
                .appQueryItem,
                .redirectQueryItem,
                .planQueryItem,
                .cycleQueryItem,
                .promoQueryItem,
                .disableCycleSelectorQueryItem,
                .disablePlanSelectorQueryItem,
                .startCheckoutQueryItem,
                .hideCloseQueryItem,
            ]
        }
    }

    func path(accountHost: URL, selector: String?) -> URL {
        guard var components = URLComponents(url: accountHost, resolvingAgainstBaseURL: false) else {
            return accountHost
        }

        guard let selector else {
            components.path = "/dashboard"
            return components.url ?? accountHost
        }

        components.path = "/lite"
        components.fragment = "selector=\(selector)"
        components.queryItems = queryItems

        return components.url ?? accountHost
    }
}

/// This dependency is used to "fork" the current session in other contexts, such as a web browser or network extension.
///
/// This allows the other contexts to access current session data without needing to log in.
///
/// - Warning: It is *very* important to make sure that you are providing the correct context to `SessionService`.
public struct SessionService: DependencyKey {
    public enum SelectorContext {
        case webLogin
        case appContext(AppContext)

        public var clientId: String {
            switch self {
            case .webLogin:
                return "web-account-lite"
            case let .appContext(context):
                @Dependency(\.appInfo) var appInfo
                return appInfo.clientId(forContext: context)
            }
        }
    }

    public var selector: (SelectorContext) async throws -> String
    public var sessionCookie: () -> HTTPCookie?

    public init(
        selector: @escaping (SelectorContext) async throws -> String,
        sessionCookie: @escaping () -> HTTPCookie?
    ) {
        self.selector = selector
        self.sessionCookie = sessionCookie
    }

    public static let liveValue: SessionService = {
        @Dependency(\.networking) var networking

        return SessionService(
            selector: { context in
                let forkRequest = ForkSessionRequest(
                    useCase: .getSelector(
                        clientId: context.clientId,
                        independent: false
                    )
                )

                let response: ForkSessionResponse = try await networking.perform(request: forkRequest)
                return response.selector
            },
            sessionCookie: { networking.sessionCookie }
        )
    }()

    // You'll have to make sure that the test using it will provide a mock Networking value
    public static let testValue: SessionService = liveValue
}

public extension SessionService {
    func getPlanSession(mode: PlanSession) async -> URL? {
        @Dependency(\.networking) var networking
        guard let accountHost = URL(string: networking.apiService.dohInterface.getAccountHost()) else {
            log.error("Failed to fork session, invalid Account Host URL", category: .app)
            return nil
        }
        do {
            let selector = try await selector(.webLogin)
            return mode.path(accountHost: accountHost, selector: selector)
        } catch {
            log.error(
                "Failed to fork session, using default account url",
                category: .app, metadata: ["error": "\(error)"]
            )
            return mode.path(accountHost: accountHost, selector: nil)
        }
    }

    func getUpgradePlanSession(url: String) async -> String {
        do {
            let selector = try await selector(.webLogin)
            return url + "#selector=" + selector
        } catch {
            log.error(
                "Failed to fork session, using default account url",
                category: .app, metadata: ["error": "\(error)"]
            )
            return url
        }
    }

    func getExtensionSessionSelector(extensionContext: AppContext) async throws -> String {
        try await selector(.appContext(extensionContext))
    }
}

public extension DependencyValues {
    var sessionService: SessionService {
        get { self[SessionService.self] }
        set { self[SessionService.self] = newValue }
    }
}

private extension URLQueryItem {
    static let actionQueryItem = URLQueryItem(name: "action", value: "subscribe-account")
    static let fullscreenQueryItem = URLQueryItem(name: "fullscreen", value: "off")
    static let redirectQueryItem = URLQueryItem(name: "redirect", value: "protonvpn://refresh")
    static let typeQueryItem = URLQueryItem(name: "type", value: "upgrade")
    static let appQueryItem = URLQueryItem(name: "app", value: "vpn")
    // 2y web specific
    static let planQueryItem = URLQueryItem(name: "plan", value: "vpn2024")
    static let cycleQueryItem = URLQueryItem(name: "cycle", value: "24")
    static let promoQueryItem = URLQueryItem(name: "coupon", value: "VPNINTROPRICE2024")
    static let disableCycleSelectorQueryItem = URLQueryItem(name: "disableCycleSelector", value: "true")
    static let disablePlanSelectorQueryItem = URLQueryItem(name: "disablePlanSelector", value: "true")
    static let startCheckoutQueryItem = URLQueryItem(name: "start", value: "checkout")
    static let hideCloseQueryItem = URLQueryItem(name: "hideClose", value: "true")
}
