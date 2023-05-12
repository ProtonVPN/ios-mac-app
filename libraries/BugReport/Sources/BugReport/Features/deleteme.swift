//
//  Created on 2023-05-12.
//
//  Copyright (c) 2023 Proton AG
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
import SwiftUI

typealias SceneA = QuickFixesFeature
typealias SceneB = ContactFormFeature

struct AppScene: ReducerProtocol {

    public init() {}

    public struct State: Equatable {
//        enum Route: Equatable {
//            case sceneA(SceneA.State)
//            case sceneB(SceneB.State)
//        }
//        var route: Route?
        var route: Routes.State?

//        public init() {}

    }

    enum Action: Equatable {
//        enum Route: Equatable {
//            case sceneA(SceneA.Action)
//            case sceneB(SceneB.Action)
//        }
//        case route(Route)
        case route(Routes.Action)

    }

    struct Routes: Equatable {
        enum State: Equatable {
            case sceneA(SceneA.State)
            case sceneB(SceneB.State)
        }

        enum Action: Equatable {
            case sceneA(SceneA.Action)
            case sceneB(SceneB.Action)
        }
    }

    public var body: some ReducerProtocol<State, Action> {

        Reduce { state, action in
            switch action {
                case .route(.sceneA(_)):
                    return .none
                case .route(.sceneB(_)):
                    return .none
            }
        }
        // Static method 'buildExpression' requires the types
        // 'AppScene.Action' and 'AppScene.Action.Route'
        // be equivalent
        .ifLet(\.route, action: /Action.route) {
            EmptyReducer()
                .ifCaseLet(/Routes.State.sceneA, action: /Routes.Action.sceneA) {
                    SceneA()
                }
//                .ifCaseLet(/State.Route.sceneB, action: /Action.Route.sceneB) {
//                    SceneB()
//                }
        }

    }

    public struct View: SwiftUI.View {

        private let store: Store<State, Action>

        public init(store: Store<State, Action>) {
            self.store = store
        }

        public var body: some SwiftUI.View {
            IfLetStore(store.scope(state: \.route, action: AppScene.Action.route)) { routeStore in
                SwitchStore(routeStore) {
                    CaseLet(state: /Routes.State.sceneA,
                            action: Routes.Action.sceneA) { _ in
//                        SceneA.View(store: $0)
                        EmptyView()
                    }
                    CaseLet(state: /Routes.State.sceneB,
                            action: Routes.Action.sceneB) { _ in
//                        SceneB.View(store: $0)
                        EmptyView()
                    }
                    Default {
                        ProgressView("Something...")
                    }
                }
            }
        }

    }

}
