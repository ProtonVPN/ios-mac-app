//
//  Created on 02/09/2024.
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

import SwiftUI
import Modals
import Theme
import ComposableArchitecture
import Home
import VPNAppCore
import Strings

@available(iOS 16.0, *)
struct ChangeServerModal: View {
    var store: StoreOf<ChangeServerFeature>

    @Dependency(\.date) var date

    @State private var sheetHeight: CGFloat = .zero

    var body: some View {
        WithPerceptionTracking {
            let dateFinished = store.dateFinished
            let totalDuration = store.totalDuration
            /// TimelineView only works when I specify all 3 dates below,
            /// though we really only need one, the `dateFinished`
            TimelineView(.explicit([.now, dateFinished, dateFinished + 1])) { timeline in
                VStack(spacing: .themeSpacing12) {
                    ReconnectCountdown(dateFinished: dateFinished,
                                       totalDuration: totalDuration)
                    .padding(.top, .themeSpacing48)
                    .padding(.bottom, .themeSpacing16)

                    if dateFinished > date.now {
                        Group {
                            Text(Localizable.upsellSpecificLocationTitle)
                                .themeFont(.body2(emphasised: true))
                                .foregroundStyle(Color(.text))
                            Text(Localizable.upsellSpecificLocationSubtitle2)
                                .themeFont(.body3(emphasised: false))
                                .foregroundStyle(Color(.text, .weak))
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                    }
                    Group {
                        if dateFinished > date.now {
                            upgradeButton
                        } else {
                            changeServerButton
                        }
                    }
                    .padding(.vertical, .themeSpacing8)
                }
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .overlay {
            GeometryReader { geometry in
                Color.clear.preference(key: InnerHeightPreferenceKey.self,
                                       value: geometry.size.height)
            }
        }
        .onPreferenceChange(InnerHeightPreferenceKey.self) { newHeight in
            sheetHeight = newHeight
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var upgradeButton: some View {
        Button {
            store.send(.buttonTapped)
        } label: {
            Text(Localizable.upgrade)
        }
        .buttonStyle(ConnectButtonStyle())
    }

    @ViewBuilder
    private var changeServerButton: some View {
        Button {
            store.send(.buttonTapped)
        } label: {
            Text(Localizable.changeServer)
        }
        .buttonStyle(ChangeServerButtonStyle(isActive: true))
    }
}

@available(iOS 17, *)
#Preview("In Progress", traits: .sizeThatFitsLayout) {
    let availability: ServerChangeAuthorizer.ServerChangeAvailability
    availability = .unavailable(until: .now + 15,
                                duration: 15,
                                exhaustedSkips: false)
    return ChangeServerModal(store: .init(initialState: .init(serverChangeAvailability: availability)) {
        ChangeServerFeature()
    })
    .frame(width: 375)
}

@available(iOS 17, *)
#Preview("Completed", traits: .sizeThatFitsLayout) {
    ChangeServerModal(store: .init(initialState: .init(serverChangeAvailability: .available)) {
        ChangeServerFeature()
    })
    .frame(width: 375)
}
