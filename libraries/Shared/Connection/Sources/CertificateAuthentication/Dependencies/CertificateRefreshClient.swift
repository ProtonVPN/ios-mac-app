//
//  Created on 25/06/2024.
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
import ExtensionIPC
import ConnectionFoundations

struct CertificateRefreshClient: DependencyKey {
    var refreshCertificate: () async throws -> CertificateRefreshResult
    var pushSelector: () async throws -> Void
}

extension DependencyValues {
    var certificateRefreshClient: CertificateRefreshClient {
        get { self[CertificateRefreshClient.self] }
        set { self[CertificateRefreshClient.self] = newValue }
    }
}

extension CertificateRefreshClient {

    public static let liveValue: CertificateRefreshClient = .init(
        refreshCertificate: {
            @Dependency(\.tunnelMessageSender) var messageSender

            let request = WireguardProviderRequest.refreshCertificate(features: nil)
            let response = try await messageSender.send(request)

            switch response {
            case .ok:
                return .ok

            case .error(let message):
                return .ipcError(message: message)

            case .errorSessionExpired:
                return .sessionMissingOrExpired

            case .errorNeedKeyRegeneration:
                return .requiresNewKeys

            case .errorTooManyCertRequests(let retryAfter):
                return .tooManyCertRequests(retryAfter: retryAfter)
            }
        },
        pushSelector: {
            @Dependency(\.sessionService) var sessionService
            @Dependency(\.tunnelMessageSender) var messageSender

            let selector = try await sessionService.selector()
            let cookie = sessionService.sessionCookie()
            let request = WireguardProviderRequest.setApiSelector(selector, withSessionCookie: cookie)
            let response = try await messageSender.send(request)

            guard case .ok = response else {
                // Unlike during certificate refresh, we don't expect any non-ok responses
                throw "Unexpected ipc result: \(response)"
            }
        }
    )
}
