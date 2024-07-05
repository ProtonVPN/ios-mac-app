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
import ConnectionFoundations
import enum ExtensionIPC.WireguardProviderRequest
import Ergonomics
import struct Domain.Server

// TODO: Consider splitting into separate loading/refreshing reducers.
public struct CertificateAuthenticationFeature: Reducer {
    @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
    @Dependency(\.vpnKeysGenerator) var keysGenerator
    @Dependency(\.sessionService) var sessionService
    @Dependency(\.certificateRefreshClient) var refreshClient
    @Dependency(\.date) var date

    public init() { }

    @CasePathable
    public enum State: Equatable, Sendable {
        case idle
        case loading(shouldRefreshIfNecessary: Bool) // Flag prevents infinite recursion
        case loaded(FullAuthenticationData)
        case failed(CertificateAuthenticationError)
    }

    @CasePathable
    public enum Action: Sendable {
        case regenerateKeys
        case purgeCertificate
        case clearEverything
        case loadAuthenticationData // load stored data, potentially refreshing missing or expired certificates
        case loadFromStorage
        case loadingFromStorageFinished(CertificateLoadingResult)
        case refreshCertificate
        case selectorPushingFinished(Result<Void, Error>)
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
                    await send(.selectorPushingFinished(Result { try await refreshClient.pushSelector() }))
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
    case loaded(FullAuthenticationData) // happy path
    case keysMissing
    case certificateMissing
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
public enum CertificateAuthenticationError: Error, Equatable {
    case keyGenerationFailed(Error)
    case wontRefresh(CertificateLoadingResult)
    case refreshWasRateLimited(retryAfter: Int?)
    case ipc(message: String)
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
}
