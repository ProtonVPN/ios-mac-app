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

struct OnboardingGetStartedView: View {
    let action: () -> Void

    var body: some View {
        VStack {
            ScrollView {
                Image("OnboardingGetStartedHeader")

                VStack(spacing: 8) {
                    ProgressView(value: 1.0)
                        .progressViewStyle(.linear)

                    Text("Step 2 of 2")
                }

                VStack {
                    Text("Help us fight censorship")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                VStack {
                    HStack {
                        VStack {

                        }

                        Toggle("Hey", isOn: .constant(true))
                    }

                    HStack {
                        VStack {

                        }

                        Toggle("Hey", isOn: .constant(true))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }

            Button("Continue", action: action)
        }
    }
}
