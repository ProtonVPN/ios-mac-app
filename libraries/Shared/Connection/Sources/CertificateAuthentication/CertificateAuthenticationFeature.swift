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

import ComposableArchitecture
import Foundation

import CommonNetworking
import CoreConnection
import enum ExtensionIPC.ProviderMessageError
import enum ExtensionIPC.WireguardProviderRequest

import protocol Domain.ProtonVPNError
import struct Domain.Server
import struct Domain.VPNConnectionFeatures
import Ergonomics
import Localization
import Strings

// TODO: Consider splitting into separate loading/refreshing reducers.
public struct CertificateAuthenticationFeature: Reducer {
    @Dependency(\.vpnAuthenticationStorage) var authenticationStorage
    @Dependency(\.connectionFeatureProvider) var featureProvider
    @Dependency(\.vpnKeysGenerator) var keysGenerator
    @Dependency(\.sessionService) var sessionService
    @Dependency(\.certificateRefreshClient) var refreshClient
    @Dependency(\.date) var date

    public init() {}

    @CasePathable
    @dynamicMemberLookup
    public enum State: Equatable, Sendable {
        case idle
        /// `shouldRefreshIfNecessary` prevents us from retrying certificate refresh infinitely.
        case loading(shouldRefreshIfNecessary: Bool)
        case loaded(FullAuthenticationData)
        case failed(CertificateAuthenticationError)
    }

    @CasePathable
    @DebugDescription
    public enum Action: Sendable {
        /// Delete keys (and certificate if it exists), then regenerate keys
        case cancelRefreshes
        case regenerateKeys
        case purgeCertificate
        case clearEverything
        case loadAuthenticationData // load stored data, potentially refreshing missing or expired certificates
        case loadFromStorage
        case loadingFromStorageFinished(CertificateLoadingResult)
        case refreshCertificate
        /// `Bool` success value circumvents compiler crash when building tests
        case refreshFinished(Result<Bool, CertificateRefreshError>)
        /// Essentially the same as `refreshFinished`, see `CertificateRefreshClient.pushSelector`
        /// `Bool` success value circumvents compiler crash when building tests
        case selectorPushingFinished(Result<Bool, CertificateRefreshError>)
        case loadingFinished(Result<FullAuthenticationData, CertificateAuthenticationError>)
    }

    package enum CancelID {
        case certificateRefreshAndRetries
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            let finishWithError: (inout State, CertificateAuthenticationError) -> Effect<Action> = { state, error in
                state = .failed(error)
                return .send(.loadingFinished(.failure(error)))
            }
            let refreshIfAllowedOrFinishWithError: (inout State, CertificateAuthenticationError) -> Effect<Action> = { state, error in
                guard case .loading(true) = state else {
                    return finishWithError(&state, error)
                }
                return .send(.refreshCertificate)
            }

            switch action {
            case .cancelRefreshes:
                return .cancel(id: CancelID.certificateRefreshAndRetries)

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
                // First, let's see if we have a certificate cached in memory
                guard case let .loaded(data) = state else {
                    log.debug("State doesn't contain cached certificate, reloading from storage", category: .connection)
                    state = .loading(shouldRefreshIfNecessary: true)
                    return .send(.loadFromStorage)
                }

                // We already cached a certificate. It should be up-to-date, `refreshTime` has passed
                guard date.now < data.certificate.refreshTime else {
                    log.debug("Cached certificate should be refreshed, reloading from storage", category: .connection)
                    state = .loading(shouldRefreshIfNecessary: true)
                    return .send(.loadFromStorage)
                }

                // Our cached certificate is most likely up-to-date. Let's see if its features are still correct
                let currentFeatures = featureProvider.connectionFeatures()
                guard data.features == currentFeatures else {
                    log.debug(
                        "Current features have evolved from stored features. Certificate needs refresh",
                        category: .connection,
                        metadata: ["storedFeatures": "\(optional: data.features)", "currentFeatures": "\(currentFeatures)"]
                    )
                    state = .loading(shouldRefreshIfNecessary: true)
                    return .send(.loadFromStorage)
                }

                log.debug("Cached certificate still valid and with up-to-date features", category: .connection, metadata: [
                    "now": "\(date.now)",
                    "refreshTime": "\(data.certificate.refreshTime)",
                    "validUntil": "\(data.certificate.validUntil)",
                ])
                return .send(.loadingFinished(.success(data)))

            case .loadFromStorage:
                return .send(.loadingFromStorageFinished(authenticationStorage.loadAuthenticationData()))

            case let .loadingFromStorageFinished(.loaded(data)):
                let storedFeatures = data.features
                let currentFeatures = featureProvider.connectionFeatures()
                guard storedFeatures == currentFeatures else {
                    log.info(
                        "Current features have evolved from stored features. Certificate needs refresh",
                        category: .connection,
                        metadata: ["storedFeatures": "\(optional: storedFeatures)", "currentFeatures": "\(currentFeatures)"]
                    )
                    return .send(.refreshCertificate)
                }
                state = .loaded(data)
                return .send(.loadingFinished(.success(data)))

            case let .loadingFromStorageFinished(failureReason):
                guard case .loading = state else {
                    reportIssue("We were expecting a loading state, but got: \(state)")
                    return .none
                }
                switch failureReason {
                case .loaded:
                    log.assertionFailure("Unexpected state after finishing loading from keychain", category: .connection)
                    return .none

                case .keysMissing:
                    // It wouldn't do us any good to regenerate keys here.
                    // We would need to also restart the tunnel with the new private key.
                    log.error("Keys should have been generated prior to starting the tunnel.")
                    return finishWithError(&state, .keysMissing)

                case .certificateExpired:
                    return refreshIfAllowedOrFinishWithError(&state, .certificateExpired)

                case .certificateMissing:
                    return refreshIfAllowedOrFinishWithError(&state, .certificateMissing)
                }

            case .refreshCertificate:
                let features = featureProvider.connectionFeatures()
                return .run { send in
                    let refreshResult = await Result { () async throws(CertificateRefreshError) in
                        try await refreshClient.refreshCertificate(features)
                        return true
                    }
                    if Task.isCancelled {
                        log.debug("Certificate refresh cancelled", category: .userCert)
                        return await send(.refreshFinished(.failure(.cancelled)))
                    }
                    return await send(.refreshFinished(refreshResult))
                }.cancellable(id: CancelID.certificateRefreshAndRetries, cancelInFlight: true)

            case .refreshFinished(.success), .selectorPushingFinished(.success):
                // Extension has completed the certificate refresh and it should be available in the keychain
                state = .loading(shouldRefreshIfNecessary: false)
                return .send(.loadFromStorage)

            case .refreshFinished(.failure(.sessionMissingOrExpired)):
                return .run { send in
                    let refreshResult = await Result { () async throws(CertificateRefreshError) in
                        try await refreshClient.pushSelector()
                        return true
                    }
                    if Task.isCancelled {
                        log.debug("Selector pushing cancelled", category: .userCert)
                        return await send(.selectorPushingFinished(.failure(.cancelled)))
                    }
                    await send(.selectorPushingFinished(refreshResult))
                }.cancellable(id: CancelID.certificateRefreshAndRetries)

            case let .selectorPushingFinished(.failure(error)), let .refreshFinished(.failure(error)):
                switch error {
                case .cancelled:
                    state = .idle
                    log.debug("Certificate refresh was cancelled", category: .userCert)
                    return .none

                case let .tooManyCertRequests(retryAfter):
                    // VPNAPPL-2893 - handle certificate refresh 429 gracefully
                    // Waiting for a retry could delay connection significantly, but this usually happens when we refresh
                    // certificates many times in a short period when changing features, not during the initial connection
                    log.info("Certificate refresh was rate limited, retry after \(optional: retryAfter)", category: .userCert)

                case .requiresNewKeys:
                    // Make sure keys are regenerated during the next connection attempt
                    authenticationStorage.deleteKeys()

                case .sessionMissingOrExpired, .sessionForkingFailed, .ipcError:
                    // There's nothing special we can do to mitigate these failures
                    log.error("Certificate refresh failed", category: .userCert, metadata: ["error": "\(error)"])
                }
                return finishWithError(&state, .refreshFailed(error))

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
public enum CertificateAuthenticationError: ProtonVPNError, Equatable {
    public static let errorDomain = "CertificateAuthenticationErrorDomain"

    case certificateMissing
    case certificateExpired
    case keysMissing
    case loadingFailed(Error)

    /// We were unable to create new keys.
    case keyGenerationFailed(Error)
    /// We will not or are unable to refresh the certificate due to the current state of the stored certs/keys.
    case refreshFailed(CertificateRefreshError)

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.charCode == rhs.charCode
    }

    public var charCode: FourCharCode {
        switch self {
        case .certificateMissing:
            "CMIS"
        case .certificateExpired:
            "CEXP"
        case .keysMissing:
            "KMIS"
        case .loadingFailed:
            "LOFA"
        case .keyGenerationFailed:
            "KGEN"
        case let .refreshFailed(refreshError):
            refreshError.charCode
        }
    }

    public var errorDescription: String? {
        includeCode(inside: Localizable.connectionErrorCertificateAuthentication)
    }

    public var underlyingError: Error? {
        switch self {
        case let .loadingFailed(error):
            error

        case let .keyGenerationFailed(error):
            error

        case let .refreshFailed(refreshError):
            refreshError.underlyingError ?? refreshError

        default:
            nil
        }
    }

    public var extraUserInfo: [String: Any]? {
        switch self {
        case let .refreshFailed(error):
            error.extraUserInfo

        default:
            nil
        }
    }
}

extension CertificateAuthenticationFeature.Action: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .regenerateKeys:
            ".regenerateKeys"
        case .purgeCertificate:
            ".purgeCertificate"
        case .clearEverything:
            ".clearEverything"
        case .loadAuthenticationData:
            ".loadAuthenticationData"
        case .loadFromStorage:
            ".loadFromStorage"
        case let .loadingFromStorageFinished(certificateLoadingResult):
            ".loadingFromStorageFinished(\(certificateLoadingResult))"
        case .refreshCertificate:
            ".refreshCertificate"
        case let .selectorPushingFinished(result):
            ".selectorPushingFinished(\(result))"
        case let .refreshFinished(result):
            ".refreshFinished(\(result))"
        case let .loadingFinished(result):
            ".loadingFinished(\(result))"
        case .cancelRefreshes:
            ".cancelRefreshes"
        }
    }
}
