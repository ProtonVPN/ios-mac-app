//
//  Created on 26/08/2024.
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
import Strings
import VPNAppCore
import Dependencies

struct HomeConnectionCardTitleView: View {
    enum State {
        case connected
        case connecting
        case disconnected(Disconnected)

        enum Disconnected {
            case noRecents
            case freeUser
            case lastConnectedTo
        }

        var title: String {
            switch self {
            case .connected:
                return Localizable.connectionCardSafelyBrowsingFrom
            case .connecting:
                return Localizable.connectionCardConnectingTo
            case .disconnected(let disconnected):
                switch disconnected {
                case .noRecents:
                    return Localizable.recommended
                case .freeUser:
                    return Localizable.connectionsFree
                case .lastConnectedTo:
                    return Localizable.connectionCardLastConnectedTo
                }
            }
        }
    }

    let state: State

    init(connectionStatus: VPNConnectionStatus, isFreeUser: Bool) {
        @Dependency(\.recentsStorage) var recentsStorage
        switch connectionStatus {
        case .disconnected, .disconnecting:
            if isFreeUser {
                state = .disconnected(.freeUser)
            } else if !recentsStorage.elements(nil).isEmpty {
                state = .disconnected(.lastConnectedTo)
            } else {
                state = .disconnected(.noRecents)
            }
        case .connected:
            state = .connected
        case .connecting, .loadingConnectionInfo:
            state = .connecting
        }
    }

    public var body: some View {
        HStack {
            Text(state.title)
                .themeFont(.body3(emphasised: false))
                .foregroundColor(Color(.text))
            Spacer()
//            Text(Localizable.actionHelp)
//                .themeFont(.caption(emphasised: true))
//                .styled(.weak)
//            IconProvider.questionCircle
//                .resizable()
//                .styled(.weak)
//                .frame(.square(16)) // TODO: [redesign, phase 2]
        }
    }
}

@available(iOS 17, *)
#Preview(traits: .sizeThatFitsLayout) {
        VStack {
            HomeConnectionCardTitleView(connectionStatus: .disconnected,
                                        isFreeUser: false)
            HomeConnectionCardTitleView(connectionStatus: .disconnected,
                                        isFreeUser: false)
            HomeConnectionCardTitleView(connectionStatus: .connecting(.defaultFastest, nil),
                                        isFreeUser: false)
            HomeConnectionCardTitleView(connectionStatus: .connected(.defaultFastest, nil),
                                        isFreeUser: false)
            HomeConnectionCardTitleView(connectionStatus: .disconnected,
                                        isFreeUser: true)
            HomeConnectionCardTitleView(connectionStatus: .connecting(.defaultFastest, nil),
                                        isFreeUser: false)
        }
}
