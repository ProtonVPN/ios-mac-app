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
        @Dependency(\.unauthKeychain) var unauthKeychain
        @Dependency(\.authKeychain) var authKeychain
        @Dependency(\.proTUNKeychainClient) var proTUNKeychainClient

        @ObservableState
        public struct State: Equatable, Sendable {
            @Presents package var alert: AlertState<Action.Alert>?
            package var content: Content
        }

        package init() {}

        public enum Action {
            case loadKeychainData
            case loadKeychainDataFinished(Result<KeychainData, Error>)
            case delegate(Delegate)
            case clearKeychainsTapped
            case clearKeychains
            case clearProTUNKeychainTapped
            case clearProTUNKeychain
            case alert(PresentationAction<Alert>)

            public enum Alert: Sendable {
                case cancel
                case confirmClear
                case confirmClearProTUN
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

                case .clearKeychainsTapped:
                    state.alert = confirmClearKeychains
                    return .none

                case .clearKeychains:
                    proTUNKeychainClient.clear()
                    unauthKeychain.clear()
                    authKeychain.clear(.clearApplicationData)
                    exit(EXIT_SUCCESS)
                    return .none

                case .clearProTUNKeychainTapped:
                    state.alert = confirmClearProTUNKeychain
                    return .none

                case .clearProTUNKeychain:
                    proTUNKeychainClient.clear()
                    return .send(.loadKeychainData)

                case .alert(.presented(.confirmClear)):
                    return .send(.clearKeychains)

                case .alert(.presented(.confirmClearProTUN)):
                    return .send(.clearProTUNKeychain)

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
                authKeychainData: authKeychainData,
                unauthKeychainData: unauthKeychainData,
                proTUNCaches: proTUNKeychainClient.caches()
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

        private var confirmClearProTUNKeychain: AlertState<Action.Alert> {
            AlertState(
                title: { TextState("Clear ProTUN keychain?") },
                actions: {
                    ButtonState(role: .cancel, action: .send(.cancel), label: { TextState("Cancel") })
                    ButtonState(role: .destructive, action: .send(.confirmClearProTUN), label: { TextState("Clear") })
                },
                message: {
                    TextState(
                        """
                        This deletes the cached ProTUN certificate, private key and API session.\n
                        For best results, ensure ProTUN is disconnected before clearing the cache.
                        """
                    )
                }
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
            package let authKeychainData: AuthKeychainData?
            package let unauthKeychainData: AuthKeychainData?
            package let proTUNCaches: [ProTUNCache]
        }

        struct AuthKeychainData: Equatable, Sendable {
            package let username: String
            package let accessToken: String
            package let refreshToken: String
            package let sessionId: String
            package let userId: String?
            package let scopes: [String]
        }
    }
#endif
