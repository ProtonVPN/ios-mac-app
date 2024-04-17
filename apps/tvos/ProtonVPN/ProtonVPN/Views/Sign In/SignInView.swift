//
//  Created on 23/04/2024.
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

struct SignInView: View {
    @Binding var path: NavigationPath
    @Environment(User.self) private var user: User

    enum Destination: String {
        case settings
    }

    @State var code: String?
    let networkClient = NetworkClient()

    var body: some View {
        VStack {
            Image(.vpnWordmarkNoBg)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 290)
            Text("Sign in")
                .font(.title)
            HStack {
                VStack {
                    Text("Scan the QR code")
                    QRCodeView(string: "www.protonvpn.com/tv")
                }
                Spacer()
                Text("Or")
                Spacer()
                VStack(spacing: .themeSpacing32) {
                    StepView(title: "Go to protonvpn.com/tv", stepNumber: 1)
                    StepView(title: "Sign in to your Proton Account", stepNumber: 2)
                    if let code {
                        StepView(title: "Enter the code \(code)", stepNumber: 3)
                    } else {
                        StepView(title: "Enter the code (retrieving...)", stepNumber: 3)
                    }
                }
                .frame(maxWidth: 800)
            }
            .font(.title2)
            .foregroundStyle(Color(.text, .weak))
        }
        .navigationDestination(for: Destination.self) { destination in
            switch destination {
            case .settings:
                SettingsView(path: $path)
            }
        }
        .task {
            do {
                code = try await networkClient.fetchSignInCode()
                user.username = try await networkClient.forkSession()
                path.append(Destination.settings)
            } catch {
                print("login failed")
            }
        }
    }
}

struct StepView: View {
    let title: String
    let stepNumber: Int
    var body: some View {
        HStack(alignment: .top) {
            Text("\(stepNumber).")
            Text(title)
            Spacer(minLength: 0)
        }
    }
}
