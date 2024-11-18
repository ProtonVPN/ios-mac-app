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
    static let itemCellHeight: CGFloat = .themeSpacing64

    let item: RecentConnection
    let isConnected: Bool
    let isLastItem: Bool
    let sendAction: RecentsFeature.ActionSender

    @ScaledMetric
    private var iconSize: CGFloat = 16

    @Dependency(\.locale)
    private var locale

    private var trailingIcon: some View {
        item.icon
            .resizable()
            .foregroundColor(.init(.icon, .weak))
            .frame(.square(iconSize))
            .padding(.trailing, .themeSpacing12)
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 0) {
            trailingIcon
            ConnectionFlagInfoView(intent: item.connection,
                                   underMaintenance: item.underMaintenance, 
                                   isPinned: item.pinned,
                                   withDivider: !isLastItem,
                                   isConnected: isConnected,
                                   images: .coreImages) { action in
                switch action {
                case .pin:
                    sendAction(.pin(item))
                case .unpin:
                    sendAction(.unpin(item))
                case .remove:
                    sendAction(.remove(item))
                }
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .frame(maxWidth: .infinity, minHeight: Self.itemCellHeight)
        .background(Color(.background))
        .onTapGesture {
            withAnimation(.easeInOut) {
                _ = sendAction(.delegate(.connect(item.connection)))
            }
        }
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            content
        }
        .accessibilityElement()
        .accessibilityLabel(item.connection.location.accessibilityText(locale: locale))
        .accessibilityAction(named: Localizable.actionConnect) {
            _ = sendAction(.delegate(.connect(item.connection)))
        }
        .accessibilityAction(named: Localizable.actionRemove) {
            _ = sendAction(.remove(item))
        }
        .accessibilityAction(
            named: item.pinned ?
                Localizable.actionHomeUnpin : Localizable.actionHomePin
        ) {
            let action: RecentsFeature.Action = item.pinned ?
                .unpin(item) : .pin(item)
            _ = sendAction(action)
        }
    }
}

extension RecentConnection {
    var icon: Image {
        return pinned ? IconProvider.pinFilled : IconProvider.clockRotateLeft
    }
}

#if DEBUG
@available(iOS 17, *)
#Preview(traits: .sizeThatFitsLayout) {
    let last = RecentConnection.sampleData.last!
    return VStack(spacing: 0) {
        ForEach(RecentConnection.sampleData) { item in
            RecentRowItemView(item: item,
                              isConnected: .random(),
                              isLastItem: item == last,
                              sendAction: { _ in () })
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
#endif
