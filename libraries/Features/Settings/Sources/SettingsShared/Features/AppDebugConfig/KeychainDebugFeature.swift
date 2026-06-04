//
//  Created on 27/03/2025 by Chris Janusiewicz.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if DEBUG
    import ComposableArchitecture
    import Domain
    import Ergonomics
    import Foundation
    import class ProtonCoreNetworking.AuthCredential
    import VPNAppCore
    import VPNShared

    @Reducer
    public struct KeychainDebugFeature: Sendable {
        @Dependency(\.vpnKeysGenerator) var generator
        @Dependency(\.vpnAuthenticationStorage) var authStorage
        @Dependency(\.unauthKeychain) var unauthKeychain
        @Dependency(\.authKeychain) var authKeychain

        @ObservableState
        public struct State: Equatable, Sendable {
            @Presents package var alert: AlertState<Action.Alert>?
            package var content: Content
        }

        package init() {}

        public enum Action {
            case loadKeychainData
            case loadKeychainDataFinished(Result<KeychainData, Error>)
            case generateNewKeysTapped
            case generateNewKeys
            case delegate(Delegate)
            case clearKeychainsTapped
            case clearKeychains
            case alert(PresentationAction<Alert>)

            public enum Alert: Sendable {
                case cancel
                case confirmClear
                case confirmGenerate
            }

            public enum Delegate {
                case dismiss
            }
        }

        public var body: some Reducer<State, Action> {
            Reduce { state, action in
                switch action {
                case .loadKeychainData:
                    return .run { send in
                        let data = try fetchKeychainData()

                        return await send(.loadKeychainDataFinished(.success(data)))
                    }

                case let .loadKeychainDataFinished(.success(data)):
                    state.content = .loaded(data)
                    return .none

                case let .loadKeychainDataFinished(.failure(error)):
                    state.content = .failed("\(error)")
                    return .none

                case .generateNewKeysTapped:
                    state.alert = confirmGenerateKeysAlert
                    return .none

                case .generateNewKeys:
                    do {
                        let keys = try generator.generateKeys()

                        // This method being non-throwing and simply logging on failure does not inspire confidence
                        authStorage.store(keys: keys)
                    } catch {
                        state.alert = errorAlert(error: error)
                    }

                    return .send(.loadKeychainData)

                case .clearKeychainsTapped:
                    state.alert = confirmClearKeychains
                    return .none

                case .clearKeychains:
                    unauthKeychain.clear()
                    authKeychain.clear(.clearApplicationData)
                    authStorage.deleteCertificate()
                    authStorage.deleteKeys()
                    exit(0)
                    return .none

                case .alert(.presented(.confirmGenerate)):
                    return .send(.generateNewKeys)

                case .alert(.presented(.confirmClear)):
                    return .send(.clearKeychains)

                case .alert(.presented(.cancel)):
                    return .none

                case .alert(.dismiss):
                    state.alert = nil
                    return .none

                case .delegate:
                    return .none
                }
            }
        }

        private func fetchKeychainData() throws -> KeychainData {
            let keysValue = authStorage.getStoredKeys()
            let certificateValue = authStorage.getStoredCertificate()
            let features = authStorage.getStoredCertificateFeatures()

            let keys = keysValue.map { value in
                VPNAuthKeychainData.Keys(
                    privateKey: value.privateKey.derRepresentation,
                    publicKey: value.publicKey.derRepresentation
                )
            }
            let certificate = certificateValue.map { value in
                VPNAuthKeychainData.Certificate(
                    pem: value.certificate,
                    expiry: value.validUntil,
                    features: features
                )
            }
            let vpnAuthKeychainData = VPNAuthKeychainData(keys: keys, certificate: certificate)

            let authCredentials: AuthCredentials? = authKeychain.fetch(forContext: .mainApp)
            let unauthCredentials: AuthCredential? = unauthKeychain.fetch()

            let authKeychainData: AuthKeychainData? = authCredentials.map {
                .init(
                    username: $0.username,
                    accessToken: $0.accessToken,
                    refreshToken: $0.refreshToken,
                    sessionId: $0.sessionId,
                    userId: $0.userId,
                    scopes: $0.scopes
                )
            }
            let unauthKeychainData: AuthKeychainData? = unauthCredentials.map {
                .init(
                    username: $0.userName,
                    accessToken: $0.accessToken,
                    refreshToken: $0.refreshToken,
                    sessionId: $0.sessionID,
                    userId: $0.userID,
                    scopes: []
                )
            }

            return KeychainData(
                vpnAuthKeychainData: vpnAuthKeychainData,
                authKeychainData: authKeychainData,
                unauthKeychainData: unauthKeychainData
            )
        }

        private var confirmClearKeychains: AlertState<Action.Alert> {
            AlertState(
                title: { TextState("Clear keychains and exit?") },
                actions: {
                    ButtonState(role: .cancel, action: .send(.cancel), label: { TextState("Cancel") })
                    ButtonState(role: .destructive, action: .send(.confirmClear), label: { TextState("Clear and exit") })
                },
                message: { TextState("Are you sure?") }
            )
        }

        private var confirmGenerateKeysAlert: AlertState<Action.Alert> {
            AlertState(
                title: { TextState("Generate new keys?") },
                actions: {
                    ButtonState(role: .cancel, action: .send(.cancel), label: { TextState("Cancel") })
                    ButtonState(role: .destructive, action: .send(.confirmGenerate), label: { TextState("Generate") })
                },
                message: { TextState("Are you sure? This is irreversible and will not clear any existing certificates.") }
            )
        }

        private func errorAlert(error: Error) -> AlertState<Action.Alert> {
            AlertState(
                title: { TextState("Key generation failed") },
                actions: {
                    ButtonState(role: .none, action: .send(.cancel), label: { TextState("Cancel") })
                },
                message: { TextState(String(describing: error)) }
            )
        }
    }

    public extension KeychainDebugFeature {
        @CasePathable
        enum Content: Equatable, Sendable {
            case none
            case loading
            case loaded(KeychainData)
            case failed(String)
        }

        struct KeychainData: Equatable, Sendable {
            public let vpnAuthKeychainData: VPNAuthKeychainData
            public let authKeychainData: AuthKeychainData?
            public let unauthKeychainData: AuthKeychainData?
        }

        struct AuthKeychainData: Equatable, Sendable {
            public let username: String
            public let accessToken: String
            public let refreshToken: String
            public let sessionId: String
            public let userId: String?
            public let scopes: [String]
        }

        struct VPNAuthKeychainData: Equatable, Sendable {
            public let keys: Keys?
            public let certificate: Certificate?

            public struct Keys: Equatable, Sendable {
                public let privateKey: String
                public let publicKey: String
            }

            public struct Certificate: Equatable, Sendable {
                public let pem: String
                public let expiry: Date
                public let features: VPNConnectionFeatures?
            }
        }
    }
#endif
