//
//  Created on 16/06/2023.
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

import SwiftUI

import ComposableArchitecture

/// Alternative to NavigationLinkStore. Does not display the otherwise mandatory disclosure indicator of the
/// NavigationLink
public struct CustomNavigationLinkStore<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Destination: View,
  Label: View
>: View {
    let store: Store<PresentationState<State>, PresentationAction<Action>>
    let toDestinationState: (State) -> DestinationState?
    let fromDestinationAction: (DestinationAction) -> Action
    let onTap: () -> Void
    let destination: (Store<DestinationState, DestinationAction>) -> Destination
    let label: () -> Label

    public init(
        _ store: Store<PresentationState<State>, PresentationAction<Action>>,
        state toDestinationState: @escaping (State) -> DestinationState?,
        action fromDestinationAction: @escaping (DestinationAction) -> Action,
        onTap: @escaping () -> Void,
        @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.store = store
        self.toDestinationState = toDestinationState
        self.fromDestinationAction = fromDestinationAction
        self.onTap = onTap
        self.destination = destination
        self.label = label
    }

    public var body: some View {
        ZStack {
            label()
            NavigationLinkStore(
                store,
                state: toDestinationState,
                action: fromDestinationAction,
                onTap: { },
                destination: destination,
                label: { EmptyView() }
            )
            .frame(.square(0))
            .opacity(0)
        }.onTapGesture { onTap() }
    }
}
