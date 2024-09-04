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

struct ChangeServerModal: View {
    var store: StoreOf<ChangeServerFeature>

    @Dependency(\.date) var date

    var body: some View {
        /// TimelineView only works when I specify all 3 dates below,
        /// though we really only need one, the `dateFinished`
        TimelineView(.explicit([.now, store.dateFinished, store.dateFinished + 1])) { timeline in
            VStack(spacing: .themeSpacing12) {

                ReconnectCountdown(dateFinished: store.dateFinished,
                                   totalDuration: store.totalDuration)
                .padding(.top, .themeSpacing48)
                .padding(.bottom, .themeSpacing16)

                if store.dateFinished > date.now {
                    Group {
                        Text(Localizable.upsellSpecificLocationTitle)
                            .themeFont(.body2(emphasised: true))
                            .foregroundStyle(Color(.text))
                        Text(Localizable.upsellSpecificLocationSubtitle2)
                            .themeFont(.body3(emphasised: false))
                            .foregroundStyle(Color(.text, .weak))
                    }
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                }
                Spacer(minLength: 0)
                if store.dateFinished > date.now {
                    upgradeButton
                } else {
                    changeServerButton
                }
            }
        }
        .padding(.vertical, .themeSpacing8)
        .padding(.horizontal, .themeSpacing16)
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
}

@available(iOS 17, *)
#Preview("Completed", traits: .sizeThatFitsLayout) {
    ChangeServerModal(store: .init(initialState: .init(serverChangeAvailability: .available)) {
        ChangeServerFeature()
    })
}
