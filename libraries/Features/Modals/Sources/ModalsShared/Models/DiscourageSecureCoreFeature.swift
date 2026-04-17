//
//  Created on 22/01/2026.
//
//  Copyright (c) 2026 Proton AG
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
import VPNAppCore

@Reducer
public struct DiscourageSecureCoreFeature {
    private let onActivate: (() -> Void)?
    private let onCancel: (() -> Void)?

    public init(
        onActivate: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.onActivate = onActivate
        self.onCancel = onCancel
    }

    @ObservableState
    public struct State: Equatable {
        var dontShowAgain: Bool

        public init(dontShowAgain: Bool = false) {
            self.dontShowAgain = dontShowAgain
        }
    }

    @CasePathable
    public enum Action: Equatable {
        case learnMoreTapped
        case activateTapped
        case cancelTapped
        case toggleDontShowAgain
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case activateTapped
            case cancelTapped
        }
    }

    @Shared(.discourageSecureCore) private var discourageSecureCore
    @Dependency(\.linkOpener) private var linkOpener

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleDontShowAgain:
                state.dontShowAgain.toggle()
                $discourageSecureCore.withLock { $0 = !state.dontShowAgain }
                return .none

            case .learnMoreTapped:
                linkOpener.open(.learnMore)
                return .none

            case .activateTapped:
                return .merge(
                    .send(.delegate(.activateTapped)),
                    .run { @MainActor _ in
                        onActivate?()
                    }
                )

            case .cancelTapped:
                return .merge(
                    .send(.delegate(.cancelTapped)),
                    .run { @MainActor _ in
                        onCancel?()
                    }
                )

            case .delegate:
                return .none
            }
        }
    }
}
