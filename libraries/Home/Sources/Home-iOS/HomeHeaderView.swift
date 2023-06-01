//
//  Created on 01.06.23.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation
import SwiftUI

import Dependencies

import Home
import Strings
import VPNShared
import Theme

struct HomeHeaderView: View {
    @Dependency(\.locale) var locale

    let connected: Bool
    let location: ConnectionSpec.Location

    var countryName: String {
        location.text(locale: locale)
    }

    let notchOffset: CGFloat
    let mapHeight: CGFloat

    @State var opacity: CGFloat = 1

    var gradientColor: Color {
        Color(.background, connected ? .success : .danger)
            .opacity(0.5)
    }

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Theme.Asset.icLockOpenFilled2
                    .swiftUIImage
                    .styled(.danger)
                    .accessibilityHidden(true)
                Text(Localizable.homeUnprotectedHeader)
                    .themeFont(.body1(.semibold))
                    .styled()
                    .padding(.themeSpacing4)
                    .accessibilityHint(Localizable.homeUnprotectedAccessibilityHint)
                HStack(spacing: 0) {
                    Text(countryName)
                        .themeFont(.body2())
                        .styled()
                    Text("・")
                        .themeFont()
                        .styled()
                    Text("158.6.140.191")
                        .themeFont(.body2())
                        .styled(.weak)
                }
                .accessibilityElement()
                .accessibilityLabel(Localizable.homeUnprotectedAccessibilityLabel(countryName))
                .padding(.themeSpacing4)
                .background(Color(.background).opacity(0.5))
                .cornerRadius(.themeRadius4)
            }
            .opacity(opacity)
            .frame(maxWidth: .infinity)
            .offset(y: proxy.headerOffset + notchOffset)
            .background(
                LinearGradient(
                    colors: [gradientColor, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            )
            .onChange(of: proxy.headerOffset) { newValue in
                guard newValue > 0 else { return }

                opacity = 1 - min(newValue / (mapHeight / 2), 1)
            }
        }
    }
}

private extension GeometryProxy {
    /// Header stays stationary regardless of scrolling.
    var headerOffset: CGFloat {
        -scrollOffset
    }
}
