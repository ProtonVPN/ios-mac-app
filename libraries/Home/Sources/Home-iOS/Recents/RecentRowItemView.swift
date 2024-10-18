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
    static let buttonPadding: CGFloat = .themeSpacing16
    static let itemCellHeight: CGFloat = .themeSpacing64

    let item: RecentConnection
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
                                   withDivider: true,
                                   images: .coreImages) { action in
                switch action {
                case .pin:
                    sendAction(.pin(item.connection))
                case .unpin:
                    sendAction(.unpin(item.connection))
                case .remove:
                    sendAction(.remove(item.connection))
                }
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .frame(maxWidth: .infinity, minHeight: Self.itemCellHeight)
        .background(Color(.background))
        .cornerRadius(.themeRadius12)
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
}

extension RecentConnection {
    var icon: Image {
        return pinned ? IconProvider.pinFilled : IconProvider.clockRotateLeft
    }
}

#if DEBUG
@available(iOS 17, *)
#Preview {
    RecentRowItemView(item: .sampleData.randomElement()!, sendAction: { _ in () })
}
#endif
