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
import Ergonomics
import HomeShared
import Theme
import VPNAppCore
import Dependencies
import ComposableArchitecture
import var ProtonCoreUIFoundations.IconProvider

struct HomeConnectionCardHeader: View {
    private let model: ConnectionCardHeaderModel
    private let actionSender: HomeConnectionCardFeature.ActionSender

    init(model: ConnectionCardHeaderModel, actionSender: @escaping HomeConnectionCardFeature.ActionSender) {
        self.model = model
        self.actionSender = actionSender
    }

    var body: some View {
        HStack {
            titleView
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

    @ViewBuilder private var titleView: some View {
        if let action {
            Button {
                actionSender(action)
            } label: {
                title
            }
        } else {
            title
        }
    }

    private var title: some View {
        HStack {
            Text(titleString)
                .themeFont(.body3(emphasised: false))
            if shouldShowDropdownChevron {
                IconProvider.chevronDownFilled
            }
        }
        .foregroundColor(Color(.text))
    }

    private var action: HomeConnectionCardFeature.Action? {
        switch model {
        case .disconnected(isPaid: true):
            return .delegate(.defaultConnectionTapped)

        default:
            return nil
        }
    }

    private var shouldShowDropdownChevron: Bool {
        model == .disconnected(isPaid: true)
    }

    private var titleString: String {
        switch model {
        case .resolving:
            return Localizable.connectionCardLoading

        case .disconnected(isPaid: true):
            return Localizable.connectionCardDefaultConnection

        case .disconnected(isPaid: false):
            return Localizable.connectionsFree

        case .connecting:
            return Localizable.connectionCardConnectingTo

        case .connected:
            return Localizable.connectionCardSafelyBrowsingFrom
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: .themeSpacing8) {
        HomeConnectionCardHeader(model: .disconnected(isPaid: true), actionSender: { _ in })
        HomeConnectionCardHeader(model: .disconnected(isPaid: false), actionSender: { _ in })
        HomeConnectionCardHeader(model: .connecting, actionSender: { _ in })
        HomeConnectionCardHeader(model: .connected, actionSender: { _ in })
    }.padding()
}
