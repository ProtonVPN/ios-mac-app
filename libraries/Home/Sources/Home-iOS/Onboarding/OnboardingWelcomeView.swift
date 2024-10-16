//
//  Created on 15/10/2024.
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

@MainActor
struct OnboardingWelcomeView: View {
    let action: () -> Void

    var body: some View {
        VStack {
            ScrollView {
                Image("OnboardingWelcomeHeader")

                VStack(spacing: 8) {
                    ProgressView(value: 0.5)
                        .progressViewStyle(.linear)

                    Text("Step 1 of 2")
                }

                VStack {
                    Text("Welcome to Proton VPN")
                    Text("Browse privately, access blocked content, and enjoy digital freedom.")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                VStack {
                    HStack {
                        Image("eye-barre")
                        Text("Certified no-logs VPN")
                        Image("arrow")
                    }

                    Text("We’ll never log your internet activity or share your information with third parties.")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }

            Button("Continue", action: action)
        }
    }
}

#Preview {
    OnboardingWelcomeView(action: {})
}
