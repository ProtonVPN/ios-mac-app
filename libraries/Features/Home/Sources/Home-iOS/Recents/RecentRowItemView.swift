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
import Domain
import HomeShared
import ProtonCoreUIFoundations
import SharedViews
import Strings
import SwiftUI

struct RecentRowItemView: View {
    static let itemCellHeight: CGFloat = .themeSpacing64

    let item: RecentConnection
    let isConnected: Bool
    let sendAction: RecentsFeature.ActionSender

    @ScaledMetric private var iconSize: CGFloat = 16

    @Dependency(\.locale) private var locale

    private var leadingIcon: some View {
        item.icon
            .resizable()
            .foregroundColor(.init(.icon, .weak))
            .frame(.square(iconSize))
            .padding(.trailing, .themeSpacing12)
    }

    private var content: some View {
        ConnectionFlagInfoView(
            intent: item.connection,
            underMaintenance: item.underMaintenance,
            isPinned: item.pinned,
            isConnected: isConnected,
            images: .coreImages,
            attachedLeadingView: { AnyView(erasing: leadingIcon) }
        ) { action in
            switch action {
            case .pin:
                sendAction(.pin(item))
            case .unpin:
                sendAction(.unpin(item))
            case .remove:
                sendAction(.remove(item))
            }
        }
        .font(.body1(.semibold))
        .padding(.leading, .themeSpacing16)
        .frame(maxWidth: .infinity, minHeight: Self.itemCellHeight)
    }

    public var body: some View {
        Button {
            _ = sendAction(.delegate(.connect(item.connection, isPinned: item.pinned)))
        } label: {
            ZStack(alignment: .bottom) {
                content
            }
        }
        .buttonStyle(RecentRowButtonStyle())
        .accessibilityElement()
        .accessibilityLabel(item.connection.location.accessibilityText(locale: locale))
        .accessibilityAction(named: Localizable.actionConnect) {
            _ = sendAction(.delegate(.connect(item.connection, isPinned: item.pinned)))
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
        pinned ? IconProvider.pinFilled : IconProvider.clockRotateLeft
    }
}

#if DEBUG
    #Preview(traits: .sizeThatFitsLayout) {
        VStack(spacing: 0) {
            ForEach(RecentConnection.sampleData) { item in
                RecentRowItemView(
                    item: item,
                    isConnected: .random(),
                    sendAction: { _ in () }
                )
            }
        }
        .padding()
        .preferredColorScheme(.dark)
    }
#endif
