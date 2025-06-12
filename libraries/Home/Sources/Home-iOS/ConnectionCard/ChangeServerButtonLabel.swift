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

import ComposableArchitecture
import Ergonomics
import HomeShared
import ProtonCoreUIFoundations
import Strings
import SwiftUI

struct ChangeServerButtonLabel: View {
    let sendAction: HomeConnectionCardFeature.ActionSender
    let changeServerAllowedDate: Date

    var updateSchedule: DateSequence {
        // add 2 to end date to allow UI to render once at 0:00, and once afterwards
        DateSequence(end: changeServerAllowedDate.addingTimeInterval(2), step: 1)
    }

    @Dependency(\.date) var date

    var body: some View {
        TimelineView(.explicit(updateSchedule)) { _ in
            Button {
                sendAction(.delegate(.changeServerButtonTapped))
            } label: {
                HStack {
                    Spacer()
                    Text(Localizable.changeServer)
                        .font(.body1(.semibold))
                    Spacer()
                    if changeServerAllowedDate > date.now {
                        HStack(spacing: .themeSpacing8) {
                            IconProvider
                                .hourglass
                                .resizable()
                                .frame(.square(.themeSpacing16))
                            Text(changeServerAllowedDate
                                .timeIntervalSinceNow
                                .asColonSeparatedString(maxUnit: .hour, minUnit: .minute))
                                .font(.body2(emphasised: false))
                            Spacer()
                                .frame(width: .themeSpacing24)
                        }
                        .foregroundColor(Color(.text))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChangeServerButtonStyle(isActive: changeServerAllowedDate < date.now))
        }
    }
}

struct ChangeServerButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(.background, .weak).opacity(0.001)) // we need to give it a background in order for the button to be tappable on the whole view...
            .foregroundColor(isActive
                ? Color(.text)
                : Color(.text, .hint))
            .themeBorder(
                style: .strong,
                cornerRadius: .radius8
            )
    }
}

@available(iOS 17, *)
#Preview("Change Server Button Label", traits: .sizeThatFitsLayout) {
    VStack {
        ChangeServerButtonLabel(
            sendAction: { _ in },
            changeServerAllowedDate: Date().addingTimeInterval(60 * 60)
        )
        ChangeServerButtonLabel(
            sendAction: { _ in },
            changeServerAllowedDate: Date().addingTimeInterval(-1)
        )
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(Color(.background, .weak))
}
