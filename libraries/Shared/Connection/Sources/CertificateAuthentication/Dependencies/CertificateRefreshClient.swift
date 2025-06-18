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

import CasePaths
import Dependencies
import Foundation

import CommonNetworking
import CoreConnection
import ExtensionIPC

import Domain
import Ergonomics

/// Errors that the network extension can report while processing our requests to refresh our certificate or consume a
/// session selector
@CasePathable
public enum CertificateRefreshError: Error {
    case cancelled
    case sessionMissingOrExpired
    case sessionForkingFailed(Error)
    case requiresNewKeys
    case tooManyCertRequests(retryAfter: Int?)
    case ipcError(IPCError)

    @CasePathable
    public enum IPCError {
        /// We encountered an issue while communicating with the network extension
        case providerMessageError(ProviderMessageError)

        /// An error occurred that isn't explictly defined by the network extension
        /// This includes things like network requests timing out (for now >:) )
        case unspecified(message: String)
    }
}

struct CertificateRefreshClient: DependencyKey {
    var refreshCertificate: (VPNConnectionFeatures) async throws(CertificateRefreshError) -> Void
    var pushSelector: () async throws(CertificateRefreshError) -> Void
}

extension DependencyValues {
    var certificateRefreshClient: CertificateRefreshClient {
        get { self[CertificateRefreshClient.self] }
        set { self[CertificateRefreshClient.self] = newValue }
    }
}

extension CertificateRefreshClient {
    private static func parse(response: WireguardProviderRequest.Response) throws(CertificateRefreshError) {
        switch response {
        case .ok: // happy path
            return

        case .errorSessionExpired:
            throw .sessionMissingOrExpired

        case .errorNeedKeyRegeneration:
            throw .requiresNewKeys

        case let .errorTooManyCertRequests(retryAfter):
            throw .tooManyCertRequests(retryAfter: retryAfter)

        case let .error(message):
            throw .ipcError(.unspecified(message: message))
        }
    }

    /// Transforms `ProviderMessageError` into `CertificateRefreshError.ipcError`
    /// without needing to indent with a `do` block
    private static func send(
        request: WireguardProviderRequest
    ) async throws(CertificateRefreshError) -> WireguardProviderRequest.Response {
        @Dependency(\.tunnelMessageSender) var messageSender
        do throws(ProviderMessageError) {
            return try await messageSender.send(request)
        } catch {
            throw .ipcError(.providerMessageError(error))
        }
    }

    private static func forkSession() async throws(CertificateRefreshError) -> String {
        @Dependency(\.sessionService) var sessionService
        do {
            return try await sessionService.selector(.appContext(.wireGuardExtension))
        } catch {
            throw .sessionForkingFailed(error)
        }
    }

    public static let liveValue: CertificateRefreshClient = .init(
        refreshCertificate: { features throws(CertificateRefreshError) in
            let request = WireguardProviderRequest.refreshCertificate(features: features)
            let response = try await send(request: request)
            try parse(response: response) // if this doesn't throw, all is good
        },
        pushSelector: { () throws(CertificateRefreshError) in
            @Dependency(\.tunnelMessageSender) var messageSender
            @Dependency(\.sessionService) var sessionService

            let selector = try await forkSession()
            let cookie = sessionService.sessionCookie()
            let request = WireguardProviderRequest.setApiSelector(selector, withSessionCookie: cookie)
            let response = try await send(request: request)
            try parse(response: response) // if this doesn't throw, all is good
        }
    )
}
