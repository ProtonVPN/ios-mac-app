//
//  Created on 06/06/2025 by adam.
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

import Theme

// MARK: - Button styles

struct HermesAddResolverButtonStyle: ButtonStyle {
    private let maxWidth: CGFloat?
    private let padding: EdgeInsets?

    init(
        fillHorizontalSpace: Bool = false,
        addMinPadding: Bool = false
    ) {
        self.maxWidth = fillHorizontalSpace ? .infinity : nil
        self.padding = addMinPadding ? .init(top: 12, leading: 24, bottom: 12, trailing: 24) : nil
    }

    @ViewBuilder
    private func withAppropriatePadding(_ view: some View) -> some View {
        if let padding {
            view.padding(padding)
        } else {
            view
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let style: AppTheme.Style = configuration.isPressed ? [.interactive, .active] : [.interactive]

        return withAppropriatePadding(configuration.label.font(.body1(.semibold)))
            .frame(maxWidth: maxWidth, minHeight: 48)
            .foregroundColor(Color(.text, .primary))
            .background(Color(.background, style))
            .cornerRadius(.themeRadius8)
    }
}

extension ButtonStyle where Self == HermesAddResolverButtonStyle {
    static func hermesAddResolver(fillHorizontalSpace: Bool = false, addMinPadding: Bool = false) -> HermesAddResolverButtonStyle {
        HermesAddResolverButtonStyle(fillHorizontalSpace: fillHorizontalSpace, addMinPadding: addMinPadding)
    }
}

// MARK: TextField styles

struct HermesTextFieldStyle: TextFieldStyle {
    let validationState: HermesSettingsViewModel.LocationValidation

    func _body(configuration: TextField<Self._Label>) -> some View {
         configuration
            .font(.body.weight(.regular)) // set the inner Text Field Font
            .padding(.vertical, .themeSpacing12)
            .padding(.horizontal, .themeSpacing16)
            .background(backgroundBorderView)
    }

    private var backgroundBorderView: some View {
        switch validationState {
        case .empty, .valid:
            return RoundedRectangle(cornerRadius: .themeSpacing8).stroke(Color.purple)
        case .invalid, .duplicate, .unexpectedError:
            return RoundedRectangle(cornerRadius: .themeSpacing8).stroke(Color.red)
        }
    }
}

extension TextFieldStyle where Self == HermesTextFieldStyle {
    static func hermesTextFieldStyle(validationState: HermesSettingsViewModel.LocationValidation) -> HermesTextFieldStyle {
        HermesTextFieldStyle(validationState: validationState)
    }
}
