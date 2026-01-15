//
//  Created on 29/4/25 by Alex Morral.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI

import ProtonCoreLoginUI
import ProtonCoreUIFoundations

import Strings
import Theme

struct NewAccountCardView: View {
    enum Action {
        case signUp
        case signIn
    }

    private enum SuiteAppLogo: CaseIterable {
        case pass
        case mail
        case calendar
        case drive

        var image: Image {
            switch self {
            case .pass: IconProvider.passMainTransparent
            case .mail: IconProvider.mailMainTransparent
            case .calendar: IconProvider.calendarMainTransparent
            case .drive: IconProvider.driveMainTransparent
            }
        }
    }

    static let identifier: String = "NewAccountCardView"

    let actionHandler: (Action) -> Void

    var tocText: AttributedString {
        let links = ExternalLinks(clientApp: .vpn)
        var markdown = try! AttributedString(markdown:
            "[\(Localizable.termsAndConditions)](\(links.termsAndConditions)) ・ " +
                "[\(Localizable.privacyPolicy)](\(links.privacyPolicy))"
        )

        // Ensure that underlines are added to inline links
        for run in markdown.runs where run.attributes.link != nil {
            markdown[run.range].underlineStyle = .single
        }

        return markdown
    }

    var body: some View {
        VStack(spacing: .themeSpacing8) {
            HStack {
                ForEach(SuiteAppLogo.allCases, id: \.self) { logo in
                    logo.image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(.square(.themeSpacing32))
                }
                Spacer(minLength: 0)
            }
            VStack(spacing: .themeSpacing4) {
                Text(Localizable.makeTheMoveToPrivacy)
                    .font(.body1(.semibold))
                    .foregroundStyle(Color(.text))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Localizable.settingsNewAccountCardDescription)
                    .font(.body2(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, .themeSpacing8)

            PCButton(
                style: .constant(.init(mode: .solid())),
                content: .constant(.init(title: Localizable.createAccountSettingsTitle, action: { actionHandler(.signUp) }))
            )

            PCButton(
                style: .constant(.init(mode: .text)),
                content: .constant(.init(title: Localizable.logIn, action: { actionHandler(.signIn) }))
            )

            Text(tocText)
                .font(.caption)
                .foregroundStyle(Color(.text, .weak))
                .tint(Color(.text, .interactive))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.themeSpacing16)
        .background(Color(.background, .weak))
        .cornerRadius(.themeRadius12)
    }
}

#Preview {
    NewAccountCardView(actionHandler: { _ in })
}
