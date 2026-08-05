//
//  Created on 15/09/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import SharedViews
import Strings
import SwiftUI

public struct LocalAgentNoticeView: View {
    let store: StoreOf<LocalAgentNoticeFeature>

    private let minSheetHeight: CGFloat = 300.0

    public init(store: StoreOf<LocalAgentNoticeFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(iOS)
            LocalAgentNoticeContentView(store: store)
                .interactiveDismissDisabled(true)
                .presentationDragIndicator(.visible)
                .presentationDetents([.height(minSheetHeight)])
        #else
            LocalAgentNoticeContentView(store: store)
                .interactiveDismissDisabled(true)
                .frame(minWidth: 420, minHeight: minSheetHeight)
        #endif
    }
}

private struct LocalAgentNoticeContentView: View {
    let store: StoreOf<LocalAgentNoticeFeature>

    var body: some View {
        VStack(spacing: .themeSpacing16) {
            Image(systemName: "touchid")
                .font(.system(size: 48))
                .foregroundStyle(Color(.text, .normal))

            Text(
                verbatim: """
                You are connected to the VPN, but all traffic is blocked.
                You need to go to the authentication page provided by security and authenticate with your hardware key.
                After that the traffic will be enabled.
                """
            )
            .themeFont(.body3(emphasised: true))

            VStack(spacing: .themeSpacing8) {
                Button("Open 2FA") {
                    store.send(.openFidoAuthentication)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(Localizable.actionDisconnect) {
                    store.send(.disconnect)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .navigationTitle("2FA Required")
            .background(Color(.background, .normal))
            .padding()
        }
    }
}
