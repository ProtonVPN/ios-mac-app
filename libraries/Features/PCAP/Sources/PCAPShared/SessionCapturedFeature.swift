//
//  Created on 2026-05-12 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
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
import Connection
import Domain
import Strings

@Reducer
public struct SessionCapturedFeature: Equatable {
    @ObservableState
    public struct State: Equatable {
        @Shared(.captureSession) public var captureSession
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    public enum Action {
        case doneTapped
        case alert(PresentationAction<Alert>)

        @CasePathable
        public enum Alert {
            case discardFile
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .doneTapped:
                state.alert = Self.discardFileAlert
                return .none
            case .alert(.presented(.discardFile)):
                return .run { _ in
                    @Dependency(\.packetCaptureClient) var packetCaptureClient
                    _ = try await packetCaptureClient.cleanup()
                }
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    static var discardFileAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.pcapCaptureDiscardTitle) },
            actions: {
                ButtonState(
                    role: .destructive,
                    action: .send(.discardFile),
                    label: { TextState(Localizable.pcapCaptureDiscardButton) }
                )
                ButtonState(
                    role: .cancel,
                    label: { TextState(Localizable.cancel) }
                )
            },
            message: { TextState(Localizable.pcapCaptureDiscardDescription) }
        )
    }
}
