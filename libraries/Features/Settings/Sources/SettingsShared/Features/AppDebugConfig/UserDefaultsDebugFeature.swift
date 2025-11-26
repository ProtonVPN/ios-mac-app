//
//  Created on 11/02/2025.
//
//  Copyright (c) 2025 Proton AG
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
import Domain
import Foundation

@Reducer
public struct UserDefaultsDebugFeature {
    @Dependency(\.userDefaultsClient) var client

    @ObservableState
    public struct State: Equatable {
        @Presents package var alert: AlertState<Action.Alert>?
        package var isStandard: Bool
        package var content: Content
    }

    public enum Action {
        case flipBool(UserDefaultsEntry)
        case resetDefaultsTapped
        case resetDefaults
        case resetDefaultsFinished(Result<Void, Error>)
        case loadDefaults
        case loadDefaultsFinished(Result<[UserDefaultsEntry], Error>)
        case loadStandardDefaults
        case loadStandardDefaultsFinished(Result<[UserDefaultsEntry], Error>)
        case delegate(Delegate)
        case alert(PresentationAction<Alert>)

        public enum Alert {
            case cancel
            case confirmReset
        }

        public enum Delegate {
            case dismiss
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .flipBool(entry):
                client.flipBool(entry)
                return .send(.loadDefaults)

            case .loadDefaults:
                state.alert = nil
                state.content = .loading
                return .run { send in
                    let result = await Result { try await (
                        client.entries()
                    ) }
                    return await send(.loadDefaultsFinished(result))
                }

            case .loadStandardDefaults:
                state.alert = nil
                state.content = .loading
                return .run { send in
                    let result = await Result { try await (
                        client.standardEntries()
                    ) }
                    return await send(.loadDefaultsFinished(result))
                }

            case let .loadDefaultsFinished(.success(entries)):
                state.content = .loadedDefaults(entries)
                return .none

            case let .loadStandardDefaultsFinished(.success(standardEntries)):
                state.content = .loadedStandardDefaults(standardEntries)
                return .none

            case let .loadDefaultsFinished(.failure(error)), let .loadStandardDefaultsFinished(.failure(error)):
                state.content = .failed("\(error)")
                return .none

            case .resetDefaults:
                state.content = .loading
                return .run { send in
                    let result = await Result { try await client.reset() }
                    return await send(.resetDefaultsFinished(result))
                }

            case .resetDefaultsFinished(.success):
                return .send(.loadDefaults)

            case let .resetDefaultsFinished(.failure(error)):
                state.content = .failed("\(error)")
                return .none

            case .resetDefaultsTapped:
                state.alert = confirmResetAlert
                return .none

            case .alert(.presented(.confirmReset)):
                return .send(.resetDefaults)

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

    private var confirmResetAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState("Reset User Defaults?") },
            actions: {
                ButtonState(role: .cancel, action: .send(.cancel), label: { TextState("Cancel") })
                ButtonState(role: .destructive, action: .send(.confirmReset), label: { TextState("Reset") })
            },
            message: { TextState("All entries will be removed. This is irreversible.\n\nAre you sure you want to continue?") }
        )
    }
}

public extension UserDefaultsDebugFeature.State {
    @CasePathable
    enum Content: Equatable {
        case none
        case loading
        case loadedDefaults([UserDefaultsEntry])
        case loadedStandardDefaults([UserDefaultsEntry])
        case failed(String)
    }
}
