//
//  Created on 29/08/2024.
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
import ProtonCoreUIFoundations
import ComposableArchitecture
import Home
import Strings

@available(iOS 16.0, *)
struct ChangeServerButtonLabel: View {
    let sendAction: HomeConnectionCardFeature.ActionSender
    var changeServerAllowedDate: Date
    @State private var currentDate = Date.now
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var timeLeft: String {
        let timeInterval = changeServerAllowedDate.timeIntervalSince(currentDate)
        let duration = Duration(secondsComponent: Int64(timeInterval), attosecondsComponent: 0)
        return duration.formatted()
    }

    var body: some View {
        Button {
            sendAction(.changeServerButtonTapped)
        } label: {
            HStack {
                Spacer()
                Text(Localizable.changeServer)
                Spacer()
                if changeServerAllowedDate > currentDate {
                    HStack(spacing: .themeSpacing8) {
                        IconProvider.hourglass
                        Text(timeLeft)
                    }
                    .foregroundColor(Color(.text))
                }
            }
            .padding(.horizontal, .themeSpacing24)
        }
        .buttonStyle(ChangeServerButtonStyle(isActive: changeServerAllowedDate < currentDate))
        .onReceive(timer) { input in
            currentDate = input
        }
    }
}

struct ChangeServerButtonStyle: ButtonStyle {

    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body1(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundColor(isActive
                        ? Color(.text, .primary)
                        : Color(.text, .hint))
            .themeBorder(color: Color(.border, .strong),
                         lineWidth: 1,
                         cornerRadius: .radius8)
    }
}
