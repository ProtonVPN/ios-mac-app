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

struct SkipChangeServerModal: View {
    let dateFinished: Date
    let totalDuration: TimeInterval

    var body: some View {
        /// TimelineView only works when I specify all 3 dates below,
        /// though we really only need one, the `dateFinished`
        TimelineView(.explicit([.now, dateFinished, dateFinished + 1])) { timeline in
            VStack(spacing: .themeSpacing12) {

                ReconnectCountdown(dateFinished: dateFinished,
                                   totalDuration: totalDuration)
                .padding(.top, .themeSpacing48)
                .padding(.bottom, .themeSpacing32)

                if dateFinished > Date() {
                    Text("You’ve reached the maximum number of free server changes for now")
                        .themeFont(.body2(emphasised: true))
                        .foregroundStyle(Color(.text))
                        .multilineTextAlignment(.center)
                    Text("With Proton Free, you can change servers a few times per hour. Get unlimited server changes with VPN Plus.")
                        .themeFont(.body3(emphasised: false))
                        .foregroundStyle(Color(.text, .weak))
                        .multilineTextAlignment(.center)
                    Spacer()
                    Button {

                    } label: {
                        Text("Upgrade")
                    }
                    .buttonStyle(ConnectButtonStyle())
                } else {
                    Spacer()
                    Button {

                    } label: {
                        Text("Change server")
                    }
                    .buttonStyle(ChangeServerButtonStyle(isActive: true))
                }
            }
        }
        .padding(.vertical, .themeSpacing8)
        .padding(.horizontal, .themeSpacing16)
    }
}

@available(iOS 17, *)
#Preview("In Progress", traits: .sizeThatFitsLayout) {
    SkipChangeServerModal(dateFinished: Date().addingTimeInterval(5),
                          totalDuration: 30)
}

@available(iOS 17, *)
#Preview("Completed", traits: .sizeThatFitsLayout) {
    SkipChangeServerModal(dateFinished: Date().addingTimeInterval(-5),
                          totalDuration: 30)
}
