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
            switch action {
            case .loadAuthenticationData:
                state = .loading(shouldRefreshIfNecessary: true)
                return .send(.loadFromStorage)

            case .loadFromStorage:
                return .send(.loadingFromStorageFinished(authenticationStorage.loadAuthenticationData()))

            case .loadingFromStorageFinished(.loaded(let data)):
                state = .loaded(data)
                return .send(.loadingFinished(.success(data)))

            case .loadingFromStorageFinished(let failureReason):
                guard case .loading(let shouldRefresh) = state else {
                    assertionFailure("We expecting a loading state, but got: \(state)")
                    return .none
                }
                if case .keysMissing = failureReason {
                    let keys = try! keysGenerator.generateKeys()
                    authenticationStorage.store(keys: keys)
                }
                if shouldRefresh {
                    return .send(.refreshCertificate)
                }
                state = .failed(.wontRefresh(failureReason))
                return .none

            case .refreshCertificate:
                state = .loading(shouldRefreshIfNecessary: false)
                return .run { send in
                    await send(.refreshFinished(Result { try await refreshClient.refreshCertificate() }))
                }

            case .refreshFinished(.success(.ok)):
                return .send(.loadFromStorage)

            case .refreshFinished(.success(.sessionMissingOrExpired)):
                return .run { send in
                    await send(.selectorPushingFinished(Result { try await refreshClient.pushSelector() }))
                }

            case .refreshFinished(.success(.tooManyCertRequests(let retryAfter))):
                // TODO: Wait and retry
                // Waiting for a retry could increase connection delation siginificantly, but this usually happens when
                // we refresh certificates many times in a short period when changing features, and not during the
                // initial connection
                log.info("Certificate refresh was rate limited, retry after \(optional: retryAfter)")
                state = .failed(.refreshWasRateLimited(retryAfter: retryAfter))
                return .none

            case .refreshFinished(.success(.ipcError(message: let message))):
                state = .failed(.ipc(message: message))
                return .none

            case .refreshFinished(.success(.requiresNewKeys)):
                assertionFailure("Should have generated keys while fetching stored certificate")
                return .none

            case .loadingFinished(.success(let authData)):
                state = .loaded(authData)
                return .none

            case .refreshFinished(.failure(let error)), .loadingFinished(.failure(let error)):
                
                return .none

            case .selectorPushingFinished(let error):
                log.error("Failed to update extension session selector \(error)")
                state = .failed(.ipc(message: "\(error)"))
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

public enum CertificateRefreshResult: Sendable {
    case ok // happy path
    case sessionMissingOrExpired
    case requiresNewKeys
    case tooManyCertRequests(retryAfter: Int?)
    case ipcError(message: String)
}

@CasePathable
public enum CertificateAuthenticationError: Error, Equatable {
    case wontRefresh(CertificateLoadingResult)
    case refreshWasRateLimited(retryAfter: Int?)
    case ipc(message: String)
}
