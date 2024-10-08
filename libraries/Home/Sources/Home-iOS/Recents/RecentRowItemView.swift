//
//  Created on 07/10/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Home
import Domain
import SwiftUI
import Strings
import SharedViews
import ProtonCoreUIFoundations

@available(iOS 17, *)
struct RecentRowItemView: View {
    @ScaledMetric var iconSize: CGFloat = 16

    @Dependency(\.locale) private var locale

//    static let offScreenSwipeDistance: CGFloat = 1000
    static let buttonPadding: CGFloat = .themeSpacing16
    static let itemCellHeight: CGFloat = .themeSpacing64

    let item: RecentConnection
    let sendAction: RecentsFeature.ActionSender

//    @State var swipeOffset: CGFloat = 0
    @State var viewSize: CGSize = .zero
    @State var buttonLabelSize: CGSize = .zero

    private var row: some View {
        HStack(alignment: .center, spacing: 0) {
            item.icon
                .resizable()
                .foregroundColor(.init(.icon, .weak))
                .frame(.square(iconSize))
                .padding(.leading, .themeSpacing16)
                .padding(.trailing, .themeSpacing12)
            ConnectionFlagInfoView(intent: item.connection, withDivider: true)
        }
        .frame(maxWidth: .infinity, minHeight: Self.itemCellHeight)
        .saveSize(in: $viewSize)
        .background(Color(.background))
        .cornerRadius(.themeRadius12)
//        .offset(x: swipeOffset)
//        .gesture(DragGesture().onChanged(swipeChanged).onEnded(swipeEnded))
        .onTapGesture {
            withAnimation(.easeInOut) {
                _ = sendAction(.delegate(.connect(item.connection)))
            }
        }
    }

//    private var swipeAction: RecentsFeature.Action? {
//        if swipeOffset == 0 { // (no swipe)
//            return nil
//        } else if swipeOffset < 0 { // (swipe left)
//            return .remove(item.connection)
//        } else { // swipeOffset > 0 (swipe right)
//            return item.pinned ?
//                .unpin(item.connection) :
//                .pin(item.connection)
//        }
//    }

//    private var underlyingButton: any View {
//        guard let swipeAction else {
//            return Color(.background, .transparent)
//        }
//
//        return button(action: swipeAction)
//    }

    public var body: some View {
        ZStack(alignment: .bottom) {
//            AnyView(underlyingButton)
            row
        }
        .accessibilityElement()
        .accessibilityLabel(item.connection.location.accessibilityText(locale: locale))
        .accessibilityAction(named: Localizable.actionConnect) {
            _ = sendAction(.delegate(.connect(item.connection)))
        }
        .accessibilityAction(named: Localizable.actionRemove) {
            _ = sendAction(.remove(item.connection))
        }
        .accessibilityAction(
            named: item.pinned ?
                Localizable.actionHomeUnpin : Localizable.actionHomePin
        ) {
            let action: RecentsFeature.Action = item.pinned ?
                .unpin(item.connection) : .pin(item.connection)
            _ = sendAction(action)
        }
    }

    @ViewBuilder
    private func button(action: RecentsFeature.Action) -> some View {
        Button(role: action.role) {
            withAnimation(.easeOut) {
                _ = sendAction(action)
            }
        } label: {
            HStack {
                if action.role == .destructive {
                    Spacer()
                }

                AnyView(action.label)
                    .saveSize(in: $buttonLabelSize)

                if action.role == nil {
                    Spacer()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Self.buttonPadding)
        .background(action.color)
    }
//
//    func swipeChanged(_ value: DragGesture.Value) {
//        guard abs(value.translation.width) > 1 &&
//            abs(value.translation.height) < 10 else {
//            return
//        }
//
//        swipeOffset = value.translation.width * (locale.isRTLLanguage ? -1 : 1)
//    }
//
//    func swipeEnded(_ value: DragGesture.Value) {
//        let sign: CGFloat = {
//            var shouldFlip = value.translation.width < 0
//            locale.isRTLLanguage ? shouldFlip.toggle() : ()
//            return shouldFlip ? -1 : 1
//        }()
//        withAnimation(.easeOut) {
//            guard value.reached(.performAction, accordingTo: viewSize) else {
//                guard value.reached(.exposeButton, accordingTo: viewSize) else {
//                    swipeOffset = 0
//                    return
//                }
//
//                let buttonWidth = buttonLabelSize.width + (Self.buttonPadding * 2)
//                swipeOffset = sign * buttonWidth
//                return
//            }
//
//            swipeOffset = sign * Self.offScreenSwipeDistance
//            if let swipeAction {
//                _ = sendAction(swipeAction)
//            }
//        }
//    }
}

extension RecentConnection {
    public var icon: Image {
        if pinned {
            return IconProvider.pinFilled
        } else {
            return IconProvider.clockRotateLeft
        }
    }
}
