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

import ComposableArchitecture

struct SignInView: View {
    @Bindable var store: StoreOf<SignInFeature>

    static let maxElementsWidth: CGFloat = 1247

    var body: some View {
        VStack(spacing: .themeSpacing64) {
            Text("Sign in")
                .font(.title)
                .bold()

            StepView(title: "Using another device, go to",
                     accent: " protonvpn.com/appletv",
                     stepNumber: 1)
            StepView(title: "Sign in to your account.",
                     accent: nil,
                     stepNumber: 2)
            switch store.state {
            case .loadingSignInCode:
                StepView(title: "When asked for your verification code, enter (retrieving...)",
                         accent: nil,
                         stepNumber: 3)
            case .waitingForAuthentication(let code, _):
                StepView(title: "When asked for your verification code, enter",
                         accent: " \(code.userCode)",
                         stepNumber: 3)
            }
        }
        .frame(maxWidth: Self.maxElementsWidth)
        .task {
            store.send(.fetchSignInCode)
        }
    }
}

struct StepView: View {
    static let bulletPointSize: CGFloat = 56

    let title: String
    let accent: String?
    let stepNumber: Int
    var body: some View {
        HStack(alignment: .top) {
            Text("\(stepNumber)")
                .font(.body)
                .frame(.square(Self.bulletPointSize))
                .background(Color(.background, .weak))
                .clipShape(Circle())
            Text(title)
                .font(.title3)  +
            Text(accent ?? "")
                .font(.title3)
                .bold()
                .foregroundStyle(Color(.text, .interactive))
            Spacer(minLength: 0)
        }
    }
}
