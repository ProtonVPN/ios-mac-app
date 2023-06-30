//
//  Created on 22.05.23.
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

import Foundation
import SwiftUI

import ComposableArchitecture

import Home
import Strings
import Theme
import VPNAppCore

public struct HomeRecentsSectionView: View {
    let items: [RecentConnection]
    let pinnedSection: Bool
    let sendAction: HomeFeature.ActionSender

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(pinnedSection ?
                    Localizable.homeRecentsPinnedSection :
                    Localizable.homeRecentsRecentSection)
                .themeFont(.body2())
                .styled(.weak)
                .padding()
            ForEach(items) { item in
                Divider()
                    .foregroundColor(.init(.border))
                RecentRowItemView(item: item, sendAction: sendAction)
            }
        }
    }
}

struct RecentRowItemView: View {
    @ScaledMetric var iconSize: CGFloat = 16

    @Dependency(\.locale) private var locale

    static let offScreenSwipeDistance: CGFloat = 1000
    static let buttonPadding: CGFloat = .themeSpacing16
    static let itemCellHeight: CGFloat = .themeSpacing64

    let item: RecentConnection
    let sendAction: HomeFeature.ActionSender

    @State var swipeOffset: CGFloat = 0
    @State var viewSize: CGSize = .zero
    @State var buttonLabelSize: CGSize = .zero

    private var swipeableRow: some View {
        HStack(alignment: .center) {
            item.icon
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.init(.icon, .weak))
                .frame(width: iconSize, height: iconSize)
                .padding(.leading)
                .padding(.trailing, .themeSpacing12)

            ConnectionFlagInfoView(location: item.connection.location)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: Self.itemCellHeight)
        .saveSize(in: $viewSize)
        .background(Color(.background))
        .cornerRadius(.themeRadius12)
        .offset(x: swipeOffset)
        .gesture(DragGesture().onChanged(swipeChanged).onEnded(swipeEnded))
        .onTapGesture {
            withAnimation(.easeInOut) {
                _ = sendAction(.connect(item.connection))
            }
        }
    }

    private var swipeAction: HomeFeature.Action? {
        if swipeOffset == 0 { // (no swipe)
            return nil
        } else if swipeOffset < 0 { // (swipe left)
            return .remove(item.connection)
        } else { // swipeOffset > 0 (swipe right)
            return item.pinned ?
                .unpin(item.connection) :
                .pin(item.connection)
        }
    }

    private var underlyingButton: any View {
        guard let swipeAction else {
            return Color(.background, .transparent)
        }

        return button(action: swipeAction)
    }

    public var body: some View {
        ZStack {
            AnyView(underlyingButton)
            swipeableRow
        }
        .accessibilityElement()
        .accessibilityLabel(item.connection.location.accessibilityText(locale: locale))
        .accessibilityAction(named: Localizable.actionConnect) {
            _ = sendAction(.connect(item.connection))
        }
        .accessibilityAction(named: Localizable.actionRemove) {
            _ = sendAction(.remove(item.connection))
        }
        .accessibilityAction(
            named: item.pinned ?
                Localizable.actionHomeUnpin : Localizable.actionHomePin
        ) {
            let action: HomeFeature.Action = item.pinned ?
                .unpin(item.connection) : .pin(item.connection)
            _ = sendAction(action)
        }
    }

    @ViewBuilder
    private func button(action: HomeFeature.Action) -> some View {
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

    func swipeChanged(_ value: DragGesture.Value) {
        guard abs(value.translation.width) > 1 &&
            abs(value.translation.height) < 10 else {
            return
        }
        
        swipeOffset = value.translation.width
    }

    func swipeEnded(_ value: DragGesture.Value) {
        let sign: CGFloat = value.translation.width < 0 ? -1 : 1

        withAnimation(.easeOut) {
            guard value.reached(.performAction, accordingTo: viewSize) else {
                guard value.reached(.exposeButton, accordingTo: viewSize) else {
                    swipeOffset = 0
                    return
                }

                let buttonWidth = buttonLabelSize.width + (Self.buttonPadding * 2)
                swipeOffset = sign * buttonWidth
                return
            }

            swipeOffset = sign * Self.offScreenSwipeDistance
            if let swipeAction {
                _ = sendAction(swipeAction)
            }
        }
    }
}

struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon
            configuration.title
        }
    }
}

extension DragGesture.Value {
    enum Direction {
        case left
        case right
    }

    var direction: Direction? {
        guard translation.width != 0 else { return nil }

        return translation.width < 0 ? .left : .right
    }

    /// Ratios as a percentage of the view width for certain swipe/button behaviors.
    enum ThresholdRatio: CGFloat {
        /// How far should we swipe before leaving the button exposed?
        case exposeButton = 0.15
        /// How far should we swipe before performing the action?
        case performAction = 0.5
    }

    func reached(_ threshold: ThresholdRatio, accordingTo viewSize: CGSize) -> Bool {
        let thresholdWidth = threshold.rawValue * viewSize.width

        return abs(translation.width) > thresholdWidth
    }
}

extension HomeFeature.Action {
    var text: Text {
        let words: String
        switch self {
        case .connect:
            words = Localizable.actionConnect
        case .pin:
            words = Localizable.actionHomePin
        case .unpin:
            words = Localizable.actionHomeUnpin
        case .remove:
            words = Localizable.actionRemove
        default:
            words = ""
        }

        return Text(words)
            .themeFont()
            .styled(.inverted)
    }

    var icon: Image? {
        let image: Theme.ImageAsset

        switch self {
        case .pin:
            image = Theme.Asset.icPinFilled
        case .unpin:
            image = Theme.Asset.icPinSlashFilled
        case .remove:
            image = Theme.Asset.icTrash
        default:
            return nil
        }

        return image.swiftUIImage
    }

    var color: Color? {
        switch self {
        case .pin, .unpin:
            return .init(.background, [.warning, .weak])
        case .remove:
            return .init(.background, .danger)
        default:
            return nil
        }
    }

    var role: ButtonRole? {
        switch self {
        case .remove:
            return .destructive
        default:
            return nil
        }
    }

    var label: any View {
        guard let icon else {
            return text
        }

        return Label {
            text
        } icon: {
            icon
                .resizable()
                .styled(.inverted)
                .frame(width: 16, height: 16) // todo: this doesn't change size with dynamic type
        }
        .labelStyle(VerticalLabelStyle())
    }
}

extension RecentConnection: Identifiable {
    public var id: String {
        "\(connection)"
    }
}

#if DEBUG
struct Recents_Previews: PreviewProvider {
    static var previews: some View {
        let store: StoreOf<HomeFeature> = .init(initialState:
            .init(connections: [
                .init(
                    pinned: true,
                    underMaintenance: false,
                    connectionDate: .now,
                    connection: .init(location: .fastest, features: [])
                ),
                .init(
                    pinned: true,
                    underMaintenance: false,
                    connectionDate: .now,
                    connection: .init(location: .region(code: "CH"), features: [])
                ),
                .init(
                    pinned: false,
                    underMaintenance: false,
                    connectionDate: .now,
                    connection: .init(location: .region(code: "US"), features: [])
                ),
                .init(
                    pinned: false,
                    underMaintenance: false,
                    connectionDate: .now,
                    connection: .init(location: .secureCore(.fastestHop(to: "AR")), features: [])
                ),
            ],
                  connectionStatus: .init(protectionState: .protected(netShield: .random)), vpnConnectionStatus: .disconnected),
            reducer: HomeFeature()
        )
        WithViewStore(store, observe: { $0 }) { store in
            ScrollView {
                if !store.remainingPinnedConnections.isEmpty {
                    HomeRecentsSectionView(
                        items: store.remainingPinnedConnections,
                        pinnedSection: true,
                        sendAction: { _ = store.send($0) }
                    )
                }
                if !store.remainingRecentConnections.isEmpty {
                    HomeRecentsSectionView(
                        items: store.remainingRecentConnections,
                        pinnedSection: false,
                        sendAction: { _ = store.send($0) }
                    )
                }
            }
            .background(Color(.background, .normal))
        }

    }
}
#endif
