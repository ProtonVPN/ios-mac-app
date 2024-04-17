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

import SwiftUI
import Theme

struct WelcomeView: View {
    @State private var path: NavigationPath = .init()

    enum Destination: String {
        case signIn
        case createAccount
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: .themeSpacing64) {
                Image(.vpnWordmarkNoBg)
                VStack(spacing: 24) {
                    Text("Watch without being watched.")
                        .fontWeight(.bold)
                        .font(.largeTitle)

                    Text("Connect to high-speed VPN servers in %n countries and stream your favorite shows with Swiss protection.")
                        .foregroundStyle(Color(.text, .weak))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 679)
                }
                .frame(maxWidth: 880)
                HStack(spacing: .themeSpacing32) {
                    NavigationLink(value: Destination.signIn) {
                        Text("Sign In")
                            .font(.callout)
                            .padding(.horizontal, .themeSpacing16)
                            .padding(.vertical, .themeSpacing12)
                    }
                    NavigationLink(value: Destination.createAccount) {
                        Text("Create account")
                            .font(.callout)
                            .padding(.horizontal, .themeSpacing16)
                            .padding(.vertical, .themeSpacing12)
                    }
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .signIn:
                    SignInView(path: $path)
                case .createAccount:
                    RegisterView(path: $path)
                }
            }
            .background(Image(.logo))
        }
    }
}

#Preview {
    WelcomeView()
}
