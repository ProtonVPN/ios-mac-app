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

import CommonNetworking
import ComposableArchitecture
import Foundation
import ProtonCoreNetworking

@Reducer
public struct NPSModalFeature {
    public static let scoreRange: ClosedRange<Int> = 0 ... 10
    public static let maxCommentCharLength: Int = 250

    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.isPresented) private var isPresented
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var score: Int?

        public var comment: String

        public init(score: Int? = nil, comment: String = "") {
            self.score = score
            self.comment = comment
        }

        var isCommentFieldVisible: Bool {
            score != nil
        }

        var canSubmit: Bool {
            score != nil
        }
    }

    @CasePathable
    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case scoreTapped(Int)
        case submitTapped
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case submitted(score: Int, comment: String)
            case dismissed
        }
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
                return .send(.delegate(.submitted(score: score, comment: state.comment)))

            case .closeTapped:
                return .send(.delegate(.dismissed))

            case .delegate(.dismissed):
                return .run { [dismiss] _ in
                    if isPresented {
                        await dismiss()
                    }
                    @Dependency(\.networking) var networking
                    let response: NPSResponse = try await networking.perform(request: NPSRequest(useCase: .dismiss))
                    log.info("Dismiss NPS survey sent with response code: \(response.code)")
                } catch: { error, _ in
                    log.info("Failed sending NPS survey with error: \(error)")
                }

            case let .delegate(.submitted(score, comment)):
                return .run { [dismiss] _ in
                    if isPresented {
                        await dismiss()
                    }
                    @Dependency(\.networking) var networking
                    let response: NPSResponse = try await networking.perform(request: NPSRequest(useCase: .submit(score: score, comment: comment)))
                    log.info("NPS survey sent with response code: \(response.code)")
                } catch: { error, _ in
                    log.info("Failed sending NPS survey with error: \(error)")
                }

            case .binding:
                return .none
            }
        }
    }
}
