//
//  TroubleshootItemView.swift
//  ProtonVPN - Created on 15.12.2024.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import ComposableArchitecture
import ProtonCoreUIFoundations
import SwiftUI
import Theme

public struct TroubleshootRowView: View {
    @Bindable var store: StoreOf<TroubleshootItem>

    public var body: some View {
        HStack(alignment: .center, spacing: .themeSpacing16) {
            VStack(alignment: .leading, spacing: .themeSpacing4) {
                Text(store.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                AttributedText(store.description, linkColor: brandColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch store.type {
            case .alternativeRouting:
                Toggle("", isOn: Binding(
                    get: { store.alternativeRouting },
                    set: { newValue in
                        store.send(.toggleAlternativeRouting(isOn: newValue))
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: brandColor))
                .fixedSize()
            case .basic:
                EmptyView()
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing12)
    }

    private var titleColor: Color {
        #if os(iOS)
            Color(uiColor: .normalTextColor())
        #elseif os(macOS)
            Color(.color(.text, .primary))
        #endif
    }

    private var brandColor: Color {
        #if os(iOS)
            Color(uiColor: .brandColor())
        #elseif os(macOS)
            Color(.color(.text, .link))
        #endif
    }
}

private struct AttributedText: View {
    let attributedString: NSAttributedString
    let linkColor: Color

    init(_ attributedString: NSAttributedString, linkColor: Color) {
        self.attributedString = attributedString
        self.linkColor = linkColor
    }

    var body: some View {
        Text(attributedText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedText: AttributedString {
        // Apply default text attributes to the NSAttributedString
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)

        #if os(iOS)
            mutableString.addTextAttributes(
                withColor: .weakTextColor(),
                font: UIFont.systemFont(ofSize: 17),
                alignment: .left
            )
        #elseif os(macOS)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            mutableString.addAttributes([
                .font: NSFont.themeFont(.small),
                .foregroundColor: NSColor.color(.text),
                .paragraphStyle: paragraphStyle,
            ], range: fullRange)
        #endif

        var result = AttributedString(mutableString)

        // Apply brand color and underline to links while preserving other attributes
        for run in result.runs {
            if run.link != nil {
                result[run.range].foregroundColor = linkColor
                result[run.range].underlineStyle = .single
            }
        }

        return result
    }
}
