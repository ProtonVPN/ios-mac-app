//
//  Created on 2026-08-26 by Pawel Jurczyk.
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
import Foundation

@Reducer
public struct NPSModalFeature: Sendable {
    public static let scoreRange: ClosedRange<Int> = 0 ... 10
    public static let maxCommentCharLength: Int = 250

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        public var score: Int?

        public var comment: String
        public var didSubmit: Bool = false
        public var didDismiss: Bool = false
        public var submitInProgress: Bool = false

        public init(score: Int? = nil, comment: String = "", didSubmit: Bool = false) {
            self.score = score
            self.comment = comment
            self.didSubmit = didSubmit
        }

        var isCommentFieldVisible: Bool {
            score != nil
        }

        var canSubmit: Bool {
            score != nil
        }

        var submitButtonEnabled: Bool {
            (canSubmit && !submitInProgress) || didSubmit
        }
    }

    @CasePathable
    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case scoreTapped(Int)
        case submitTapped
        case submitResult(Result<Int, Error>)
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case submit(score: Int, comment: String)
            case dismiss
        }
    }

    private enum CancelID {
        case submitRequest
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .scoreTapped(score):
                state.score = score
                return .none

            case .submitTapped:
                guard let score = state.score else { return .none }
                return .send(.delegate(.submit(score: score, comment: state.comment)))

            case .closeTapped:
                return .merge(
                    .cancel(id: CancelID.submitRequest),
                    .send(.delegate(.dismiss))
                )

            case .delegate(.dismiss):
                state.didDismiss = true
                guard !state.didSubmit else {
                    return .none
                }
                return .run { _ in
                    @Dependency(\.announcementClient) var announcementClient
                    let response = try await announcementClient.sendNPSScore(.dismiss)
                    log.info("Dismiss NPS survey sent with response code: \(response.code)")
                } catch: { error, _ in
                    log.info("Failed sending NPS survey with error: \(error)")
                }

            case let .delegate(.submit(score, comment)):
                state.submitInProgress = true
                return .run { send in
                    @Dependency(\.announcementClient) var announcementClient
                    let response = try await announcementClient.sendNPSScore(.submit(score: score, comment: comment))
                    await send(.submitResult(.success(response.code)))
                } catch: { error, send in
                    await send(.submitResult(.failure(error)))
                }.cancellable(id: CancelID.submitRequest, cancelInFlight: true)

            case let .submitResult(result):
                state.submitInProgress = false
                switch result {
                case let .success(code):
                    state.didSubmit = true
                    log.info("NPS survey sent with response code: \(code)")
                case let .failure(error):
                    log.info("Failed sending NPS survey with error: \(error)")
                }
                return .none

            case .binding:
                return .none
            }
        }
    }
}
