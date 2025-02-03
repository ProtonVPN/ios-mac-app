//
//  Created on 03/12/2024.
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

import CertificateAuthentication
import CommonNetworking
import Dependencies
import Domain

extension CertificateAuthentication.SessionService: DependencyKey {
    public static let liveValue: CertificateAuthentication.SessionService = {
        @Dependency(\.networking) var networking
        @Dependency(\.appInfo) var appInfo

        return CertificateAuthentication.SessionService(
            selector: selector,
            sessionCookie: { networking.sessionCookie },
            getUpgradePlanSession: getUpgradePlanSession,
            getExtensionSessionSelector: getExtensionSessionSelector
        )
    }()

    static private func selector() async throws -> String {
        @Dependency(\.appInfo) var appInfo
        let clientId = appInfo.clientId(forContext: .wireGuardExtension)
        return try await selector(clientId: clientId)
    }

    static private func selector(clientId: String) async throws -> String {
        @Dependency(\.networking) var networking
        let forkRequest = ForkSessionRequest(useCase: .getSelector(clientId: clientId, independent: false))
        let response: ForkSessionResponse = try await networking.perform(request: forkRequest)
        return response.selector
    }


    static private func getUpgradePlanSession(url: String) async -> String {
        do {
            let selector = try await selector(clientId: "web-account-lite")
            return url + "#selector=" + selector
        } catch {
            log.error("Failed to fork session, using default account url", category: .app, metadata: ["error": "\(error)"])
            return url
        }
    }

    static private func getExtensionSessionSelector(extensionContext: AppContext) async throws -> String {
        try await selector(clientId: clientSessionId(forContext: extensionContext))
    }

    static private func clientSessionId(forContext context: AppContext) -> String {
        @Dependency(\.appInfo) var appInfo
        return appInfo.clientId(forContext: context)
    }

}
