//
//  TroubleshootRowView.swift
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

import ProtonCoreUIFoundations
import SwiftUI
import Theme

public struct TroubleshootRowView: View {
    let item: TroubleshootItem
    @State private var isOn: Bool

    public init(item: TroubleshootItem) {
        self.item = item
        if let actionable = item as? ActionableTroubleshootItem {
            _isOn = State(initialValue: actionable.isOn)
        } else {
            _isOn = State(initialValue: false)
        }
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(titleColor)

                AttributedText(item.description, linkColor: brandColor)
            }
            if let actionable = item as? ActionableTroubleshootItem {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: brandColor))
                    .onChange(of: isOn) { _, newValue in
                        actionable.set(isOn: newValue)
                    }
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var titleColor: Color {
        #if os(iOS)
            Color(uiColor: .normalTextColor())
        #elseif os(macOS)
            Color(nsColor: NSColor.color(.text, .primary))
        #endif
    }

    private var brandColor: Color {
        #if os(iOS)
            Color(uiColor: .brandColor())
        #elseif os(macOS)
            Color(nsColor: NSColor.color(.text, .link))
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
                .font: NSFont.systemFont(ofSize: 17),
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
