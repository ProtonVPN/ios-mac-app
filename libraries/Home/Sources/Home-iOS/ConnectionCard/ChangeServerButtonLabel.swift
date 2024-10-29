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
    let changeServerAllowedDate: Date

    @Dependency(\.date) var date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Button {
                sendAction(.delegate(.changeServerButtonTapped))
            } label: {
                HStack {
                    Spacer()
                    Text(Localizable.changeServer)
                    Spacer()
                    if changeServerAllowedDate > date.now {
                        HStack(spacing: .themeSpacing8) {
                            IconProvider.hourglass
                            Text(changeServerAllowedDate
                                .timeIntervalSinceNow
                                .asColonSeparatedString(maxUnit: .hour, minUnit: .minute))
                            Spacer()
                                .frame(width: .themeSpacing24)
                        }
                        .foregroundColor(Color(.text))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(ChangeServerButtonStyle(isActive: changeServerAllowedDate < date.now))
        }
    }
}

struct ChangeServerButtonStyle: ButtonStyle {

    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body1(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(.background, .weak).opacity(0.001)) // we need to give it a background in order for the button to be tappable on the whole view...
            .foregroundColor(isActive
                        ? Color(.text, .primary)
                        : Color(.text, .hint))
            .themeBorder(color: Color(.border, .strong),
                         lineWidth: 1,
                         cornerRadius: .radius8)
    }
}
