//
//  Created on 13/03/2026 by Max Kupetskyi.
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

import Combine
import ComposableArchitecture
import PaymentsShared
import SwiftUI
import UIKit

public enum PaymentsFlowRequest: Equatable, Sendable {
    case upsell(UpsellModalType)
    case directSubscriptionManagement
}

public enum PaymentsFlowEvent: Equatable, Sendable {
    case completed
    case dismissed
    case engaged(planId: String, purchaseType: PlanOptionV2.PlanType)
    case createAccountFirstRequested
}

public final class PaymentsFlowCoordinator {
    private var activeFlowCancellable: AnyCancellable?

    public init() {}

    @MainActor
    public func makeViewController(
        request: PaymentsFlowRequest,
        onEvent: ((PaymentsFlowEvent) -> Void)? = nil
    ) -> UIViewController {
        let state: PaymentsFeature.State = switch request {
        case let .upsell(upsellModalType):
            .init(presentationKind: .upsell(upsellModalType), upsellModalType: upsellModalType)
        case .directSubscriptionManagement:
            .init(presentationKind: .directSubscriptionManagement)
        }

        let store = Store(initialState: PaymentsFlowBridgeFeature.State(payments: state)) {
            PaymentsFlowBridgeFeature()
        }

        activeFlowCancellable = store.publisher.latestEvent
            .compactMap { $0 }
            .sink { event in
                onEvent?(event)
                store.send(.eventHandled)
            }

        let rootView = PlanOptionsViewV2TCA(
            store: store.scope(state: \.payments, action: \.payments)
        )
        return UIHostingController(rootView: rootView)
    }
}

@Reducer
private struct PaymentsFlowBridgeFeature {
    @ObservableState
    struct State: Equatable {
        var payments: PaymentsFeature.State
        var latestEvent: PaymentsFlowEvent?
    }

    enum Action {
        case payments(PaymentsFeature.Action)
        case eventHandled
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.payments, action: \.payments) {
            PaymentsFeature()
        }
        Reduce { state, action in
            switch action {
            case let .payments(.delegate(delegate)):
                state.latestEvent = switch delegate {
                case .completed:
                    .completed
                case .dismissed:
                    .dismissed
                case let .engaged(planId, purchaseType):
                    .engaged(planId: planId, purchaseType: purchaseType)
                case .createAccountFirstRequested:
                    .createAccountFirstRequested
                }
                return .none
            case .eventHandled:
                state.latestEvent = nil
                return .none
            case .payments:
                return .none
            }
        }
    }
}
