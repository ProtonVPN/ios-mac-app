//
//  Created on 2022-01-03.
//
//  Copyright (c) 2022 Proton AG
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

@available(iOS 14.0, macOS 11, *)
private extension ButtonStyle {
    var paddingHorizontal: CGFloat { 16 }
    var cornerRadius: CGFloat { 8 }
    var pressedColorOpacity: Double { 0.5 }
}

@available(iOS 14.0, macOS 11, *)
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colors) var colors: Colors
    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.isLoading) private var isLoading: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            #if os(macOS)
            .font(.system(size: 16, weight: .bold, design: .default))
            #endif
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            .background(ZStack(alignment: .trailing) {
                if isLoading {
                    colors.brandLight20
                    ProgressView()
                        .padding(.horizontal, paddingHorizontal)
                        .progressViewStyle(.circular)

                } else {
                    isEnabled ? colors.brand : colors.brandDark40
                }

            })
            .foregroundColor(isEnabled || isLoading ? colors.textPrimary : colors.textPrimary.opacity(0.5))
            .cornerRadius(cornerRadius)
            .opacity(configuration.isPressed && !isLoading ? 0.5 : 1)
    }
}

@available(iOS 14.0, macOS 11, *)
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colors) var colors: Colors

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            .padding(.horizontal, paddingHorizontal)
            .foregroundColor(colors.brand)
            .cornerRadius(cornerRadius)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

// MARK: - Mac only styles

@available(iOS 14.0, macOS 11, *)
struct CategoryButtonStyle: ButtonStyle {
    @Environment(\.colors) var colors: Colors
    private var horizontalPadding = 32.0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .foregroundColor(colors.textPrimary)
            .padding(.horizontal, horizontalPadding)
            .background(ZStack(alignment: .trailing) {
                colors.backgroundSecondary
                Image(systemName: "chevron.right").padding(.trailing, horizontalPadding)
            })
            .cornerRadius(cornerRadius)
    }
}

@available(iOS 14.0, macOS 11, *)
struct BackButtonStyle: ButtonStyle {
    @Environment(\.colors) var colors: Colors

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .hidden()
            .background(Image(systemName: "arrow.left").font(.system(size: 18)))
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .foregroundColor(colors.textPrimary)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}
