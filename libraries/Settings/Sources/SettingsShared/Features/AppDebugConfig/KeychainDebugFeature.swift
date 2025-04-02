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

import ComposableArchitecture
import Foundation
import Ergonomics
import VPNShared

@Reducer
public struct KeychainDebugFeature {
    @Dependency(\.vpnKeysGenerator) var generator
    @Dependency(\.vpnAuthenticationStorage) var authStorage

    @ObservableState
    public struct State: Equatable {
        @Presents package var alert: AlertState<Action.Alert>?
        package var content: Content

        //        package init(alert: AlertState<Action.Alert>? = nil) {
        //            self.alert = alert
        //        }
    }

    package init() { }

    public enum Action {
        case loadKeychainData
        case loadKeychainDataFinished(Result<State.AuthKeychainData, Error>)
        case generateNewKeysTapped
        case generateNewKeys
        case delegate(Delegate)
        case alert(PresentationAction<Alert>)

        public enum Alert {
            case cancel
            case confirm
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
                    let keysValue = authStorage.getStoredKeys()
                    let certificateValue = authStorage.getStoredCertificate()

                    let keys = keysValue.map { value in
                        State.AuthKeychainData.Keys(
                            privateKey: value.privateKey.derRepresentation,
                            publicKey: value.publicKey.derRepresentation
                        )
                    }
                    let certificate = certificateValue.map { value in
                        State.AuthKeychainData.Certificate(
                            pem: value.certificate,
                            expiry: value.validUntil
                        )
                    }

                    return await send(.loadKeychainDataFinished(.success(.init(keys: keys, certificate: certificate))))
                }

            case .loadKeychainDataFinished(.success(let data)):
                state.content = .loaded(data)
                return .none

            case .loadKeychainDataFinished(.failure(let error)):
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

            case .alert(.presented(.confirm)):
                return .send(.generateNewKeys)

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

    private var confirmGenerateKeysAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState("Generate new keys?") },
            actions: {
                ButtonState(role: .cancel, action: .send(.cancel), label: { TextState("Cancel") })
                ButtonState(role: .destructive, action: .send(.confirm), label: { TextState("Generate") })
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
            message: { TextState("\(error)") }
        )
    }
}

extension KeychainDebugFeature.State {
    @CasePathable
    public enum Content: Equatable, Sendable {
        case none
        case loading
        case loaded(AuthKeychainData)
        case failed(String)
    }

    public struct AuthKeychainData: Equatable, Sendable {
        public let keys: Keys?
        public let certificate: Certificate?

        public struct Keys: Equatable, Sendable {
            public let privateKey: String
            public let publicKey: String
        }

        public struct Certificate: Equatable, Sendable {
            public let pem: String
            public let expiry: Date
        }
    }
}
