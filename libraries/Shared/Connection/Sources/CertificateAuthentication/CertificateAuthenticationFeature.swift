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

import Foundation
import ComposableArchitecture

import CoreConnection
import CommonNetworking
import enum ExtensionIPC.WireguardProviderRequest

import Localization
import Ergonomics
import Strings
import struct Domain.Server
import protocol Domain.ProtonVPNError

// TODO: Consider splitting into separate loading/refreshing reducers.
public struct CertificateAuthenticationFeature: Reducer {
    @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
    @Dependency(\.vpnKeysGenerator) var keysGenerator
    @Dependency(\.sessionService) var sessionService
    @Dependency(\.certificateRefreshClient) var refreshClient
    @Dependency(\.date) var date

    public init() { }

    @CasePathable
    @dynamicMemberLookup
    public enum State: Equatable, Sendable {
        case idle
        case loading(shouldRefreshIfNecessary: Bool) // Flag prevents infinite recursion
        case loaded(FullAuthenticationData)
        case failed(CertificateAuthenticationError)
    }

    @CasePathable
    public enum Action: Sendable {
        /// Delete keys (and certificate if it exists), then regenerate keys
        case regenerateKeys
        case purgeCertificate
        case clearEverything
        case loadAuthenticationData // load stored data, potentially refreshing missing or expired certificates
        case loadFromStorage
        case loadingFromStorageFinished(CertificateLoadingResult)
        case refreshCertificate
        case selectorPushingFinished(Result<Bool, Error>)
        case refreshFinished(Result<CertificateRefreshResult, Error>)
        case loadingFinished(Result<FullAuthenticationData, Error>)
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            let finishWithError: (inout State, CertificateAuthenticationError) -> Effect<Action> = { state, error in
                state = .failed(error)
                return .send(.loadingFinished(.failure(error)))
            }

            switch action {
            case .regenerateKeys:
                authenticationStorage.deleteKeys() // also deletes any existing certificates
                _ = authenticationStorage.getKeys() // generates new keys
                state = .idle
                return .none

            case .purgeCertificate:
                authenticationStorage.deleteCertificate()
                state = .idle
                return .none

            case .clearEverything:
                authenticationStorage.deleteKeys() // also deletes any existing certificates
                state = .idle
                return .none

            case .loadAuthenticationData:
                if case .loaded(let data) = state, data.certificate.refreshTime > date.now {
                    return .send(.loadingFinished(.success(data)))
                }
                state = .loading(shouldRefreshIfNecessary: true)
                return .send(.loadFromStorage)

            case .loadFromStorage:
                return .send(.loadingFromStorageFinished(authenticationStorage.loadAuthenticationData()))

            case .loadingFromStorageFinished(.loaded(let data)):
                state = .loaded(data)
                return .send(.loadingFinished(.success(data)))

            case .loadingFromStorageFinished(let failureReason):
                guard case .loading(let shouldRefresh) = state else {
                    assertionFailure("We were expecting a loading state, but got: \(state)")
                    return .none
                }
                if case .keysMissing = failureReason {
                    do {
                        let keys = try keysGenerator.generateKeys()
                        authenticationStorage.store(keys: keys)
                    } catch {
                        return finishWithError(&state, .keyGenerationFailed(error))
                    }
                }
                if shouldRefresh {
                    return .send(.refreshCertificate)
                }
                return finishWithError(&state, .wontRefresh(failureReason))

            case .refreshCertificate:
                return .run { send in
                    await send(.refreshFinished(Result { try await refreshClient.refreshCertificate() }))
                }

            case .refreshFinished(.success(.ok)):
                state = .loading(shouldRefreshIfNecessary: false)
                return .send(.loadFromStorage)

            case .refreshFinished(.success(.sessionMissingOrExpired)):
                return .run { send in
                    await send(.selectorPushingFinished(Result {
                        try await refreshClient.pushSelector()
                        // returning a Bool is to circumvent a compiler build issue with Result<Void, _> & CaseKeyPaths
                        return true
                    }))
                }

            case .selectorPushingFinished(.success):
                // Extension now has a session. Let's try again
                return .send(.refreshCertificate)

            case .refreshFinished(.success(.tooManyCertRequests(let retryAfter))):
                // TODO: Wait and retry
                // Waiting for a retry could delay connection significantly, but this usually happens when we refresh
                // certificates many times in a short period when changing features, not during the initial connection
                log.info("Certificate refresh was rate limited, retry after \(optional: retryAfter)")
                return finishWithError(&state, .refreshWasRateLimited(retryAfter: retryAfter))

            case .refreshFinished(.success(.ipcError(message: let message))):
                let refreshError = CertificateAuthenticationError.ipc(message: message)
                state = .failed(refreshError)
                return .send(.loadingFinished(.failure(refreshError)))

            case .refreshFinished(.success(.requiresNewKeys)):
                assertionFailure("Should have generated keys while fetching stored certificate")
                return .none

            case .refreshFinished(.failure(let error)), .selectorPushingFinished(.failure(let error)):
                return finishWithError(&state, .unexpected(error))

            case .loadingFinished:
                // End result of this feature, to be handled by parent.
                return .none
            }
        }
    }
}

@CasePathable
public enum CertificateLoadingResult: Sendable, Equatable {
    /// Both keys and certificate are available (happy path)
    case loaded(FullAuthenticationData)
    /// The keys are missing.
    case keysMissing
    /// The certificate is missing.
    case certificateMissing
    /// The certificate is present, but expired.
    case certificateExpired
}

@CasePathable
public enum CertificateRefreshResult: Sendable {
    case ok // happy path
    case sessionMissingOrExpired
    case requiresNewKeys
    case tooManyCertRequests(retryAfter: Int?)
    case ipcError(message: String)
}

@CasePathable
public enum CertificateAuthenticationError: ProtonVPNError, Equatable {
    public static let errorDomain = "CertificateAuthenticationErrorDomain"

    /// We were unable to create new keys.
    case keyGenerationFailed(Error)
    /// We will not or are unable to refresh the certificate due to the current state of the stored certs/keys.
    case wontRefresh(CertificateLoadingResult)
    /// The API told us to wait, we will try again in a certain interval.
    case refreshWasRateLimited(retryAfter: Int?)
    /// We got a message from the extension with a specific error message.
    case ipc(message: String)
    /// An unexpected error occurred.
    case unexpected(Error)

    public static func == (lhs: CertificateAuthenticationError, rhs: CertificateAuthenticationError) -> Bool {
        switch (lhs, rhs) {
        case (.wontRefresh, .wontRefresh):
            return true

        case (.refreshWasRateLimited, .refreshWasRateLimited):
            return true

        case (.ipc, .ipc):
            return true

        case (.unexpected, .unexpected):
            return true

        case (.keyGenerationFailed, .keyGenerationFailed):
            return true

        default:
            return false
        }
    }

    public var charCode: FourCharCode {
        switch self {
        case .keyGenerationFailed:
            return "KGEN"
        case .wontRefresh:
            return "RFSH"
        case .refreshWasRateLimited:
            return "RATE"
        case .ipc:
            return "RIPC"
        case .unexpected:
            return "UNEX"
        }
    }

    public var errorDescription: String? {
        includeCode(inside: Localizable.connectionErrorCertificateAuthentication)
    }

    public var underlyingError: Error? {
        switch self {
        case let .keyGenerationFailed(error), let .unexpected(error):
            return error
        default:
            return nil
        }
    }

    public var extraUserInfo: [String: Any]? {
        var result: [String: Any] = [:]

        switch self {
        case .wontRefresh(let loadingResult):
            result["WontRefresh"] = loadingResult
        case .ipc(let message):
            result["IPCMessage"] = message
        case .refreshWasRateLimited(let retryAfter):
            result["RetryAfter"] = "\(optional: retryAfter)"
        default:
            return nil
        }

        return result
    }
}
