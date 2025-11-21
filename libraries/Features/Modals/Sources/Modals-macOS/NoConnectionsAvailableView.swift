//
//  Created on 2025-08-29 by Pawel Jurczyk.
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

import Domain
import ModalsShared
import Strings
import Theme

public struct NoConnectionsAvailableView: View {
    @Environment(\.dismiss) var dismiss

    let mode: NoConnectionsAvailableMode

    enum Constants {
        static let readableContentWidth: CGFloat = 536
        static let windowSize = AppTheme.IconSize.rect(
            width: 600,
            height: 452
        )
    }

    public init(mode: NoConnectionsAvailableMode) {
        self.mode = mode
    }

    public var body: some View {
        VStack(spacing: .themeSpacing32) {
            Asset.globeError.swiftUIImage
            VStack(spacing: .themeSpacing8) {
                Text(Localizable.noConnectionsAvailable)
                    .themeFont(.title1(emphasised: true))
                    .foregroundStyle(Color(.text))
                Text(mode.subtitle)
                    .themeFont(.title2(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: .themeSpacing16) {
                Button(Localizable.subuserAlertLoginButton) {
                    dismiss()
                }
                .buttonStyle(Theme.ThemeButtonStyle(padding: .medium, style: .primary))
                if let helpString = mode.helpString {
                    Text(helpString)
                        .themeFont(.body(emphasised: false))
                        .foregroundStyle(Color(.text, .weak))
                        .multilineTextAlignment(.center)
                        .tint(Color(.text, .link))
                }
            }
        }
        .frame(maxWidth: Constants.readableContentWidth)
        .padding(.horizontal, .themeSpacing16)
        .frame(Constants.windowSize)
        .background(Color(.background))
    }
}

#Preview {
    NoConnectionsAvailableView(mode: .noServers)
        .preferredColorScheme(.dark)
}

#Preview {
    NoConnectionsAvailableView(mode: .connectionsDisabled)
        .preferredColorScheme(.dark)
}

#Preview {
    NoConnectionsAvailableView(mode: .loadingError)
        .preferredColorScheme(.dark)
}
