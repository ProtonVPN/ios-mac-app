//
//  Created on 05.04.24.
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

import Ergonomics
import SwiftUI
import Theme

import ComposableArchitecture

struct WelcomeView: View {
    @Bindable var store: StoreOf<WelcomeFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: .themeSpacing64) {
                Spacer()
                Image(.vpnWordmarkNoBg)
                titleView
                buttonsView
                Spacer()
                availableView
            }
            .background(Image(.backgroundBrand))
            .navigationDestination(item: $store.scope(state: \.destination?.signIn,
                                                      action: \.destination.signIn)) {
                SignInView(store: $0)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.welcomeInfo, action: \.destination.welcomeInfo)) { WelcomeInfoView(store: $0) }
            .navigationDestination(item: $store.scope(state: \.destination?.codeExpired, action: \.destination.codeExpired)) { CodeExpiredView(store: $0) }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    var availableView: some View = {
        Text("Available with Proton VPN Plus", comment: "Badge title on the login page")
            .font(.caption)
            .foregroundColor(Color(.text))
            .padding(.vertical, .themeSpacing8)
            .padding(.horizontal, .themeSpacing16)
            .overlay(
                RoundedRectangle(cornerRadius: .themeRadius12)
                    .stroke(LinearGradient(colors: [Color(hex: 0x6E4BFF), // custom colors just for this
                                                    Color(hex: 0x547AEC),
                                                    Color(hex: 0x2FCCCF)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing),
                            lineWidth: 1.5)
            )
    }()

    var titleView: some View = {
        VStack(spacing: 24) {
            Text("Watch without being watched.", comment: "Subtitle on the login page")
                .fontWeight(.bold)
                .font(.title2)

            Text("Proton VPN's strict no-log policy is certified by an external audit. We'll never track you online, log your IP address or share your information with third parties.", comment: "Subtitle on the login page")
                .font(.body)
                .foregroundStyle(Color(.text, .weak))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 880)
    }()

    var buttonsView: some View {
        HStack(spacing: .themeSpacing32) {
            WelcomeButtonView(title: "Agree and Sign in", action: {
                store.send(.showSignIn)
            })
//            WelcomeButtonView(title: "Create account", action: {
//                store.send(.showCreateAccount)
//            })
        }
    }
}
