//
//  Created on 2022-01-05.
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

/// Multiline text input styled for usage in bug report form.
@available(iOS 14.0, macOS 11, *)
struct MultiLineTextInputView: View {

    var field: InputField
    @Binding var value: String
    @Environment(\.colors) var colors: Colors

    #if os(iOS)
    var titleFontSize = 13.0
    var userFontSize = 17.0
    #else
    var titleFontSize = 14.0
    var userFontSize = 14.0
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(field.label)
                .font(.system(size: titleFontSize))
                .padding(.bottom, 8)

            ZStack(alignment: .topLeading) {
                if value.isEmpty {
                    Text(field.placeholder ?? "")
                        .font(.system(size: userFontSize))
                        .foregroundColor(colors.textSecondary)
                }
                TextView(text: $value, fontSize: userFontSize)
                    .accessibilityIdentifier("Multiline input \(field.submitLabel)")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(colors.backgroundWeak)
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
}

#if os(iOS)
import UIKit

@available(iOS 14.0, *)
struct TextView: UIViewRepresentable {

    @Binding var text: String

    var fontSize: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: fontSize)
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator($text)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>

        init(_ text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            self.text.wrappedValue = textView.text
        }
    }
}

#elseif os(macOS)
import AppKit

@available(macOS 11, *)
struct TextView: NSViewRepresentable {

    @Binding var text: String

    var fontSize: CGFloat
    @Environment(\.colors) var colors: Colors

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.textContainerInset = NSSize(width: -5, height: 0) // -5 is magic number that aligns input text with placeholder
        textView.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ containerView: NSScrollView, context: Context) {
        guard let textView = containerView.documentView as? NSTextView else {
            return
        }
        let length = text.count
        let value = NSMutableAttributedString(string: text)
        value.addAttribute(NSAttributedString.Key.font, value: font, range: NSRange(location: 0, length: length))
        value.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor, range: NSRange(location: 0, length: length))

        textView.textStorage?.setAttributedString(value)
        if !context.coordinator.selectedRanges.isEmpty {
            textView.selectedRanges = context.coordinator.selectedRanges
        }
    }

    private var textColor: NSColor {
        return NSColor(colors.textPrimary)
    }

    private var font: NSFont {
        return NSFont.systemFont(ofSize: fontSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator($text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectedRanges: [NSValue] = []

        init(_ text: Binding<String>) {
            self.text = text
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            self.text.wrappedValue = textView.string
            self.selectedRanges = textView.selectedRanges
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            self.text.wrappedValue = textView.string
            self.selectedRanges = textView.selectedRanges
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            self.text.wrappedValue = textView.string
            self.selectedRanges = textView.selectedRanges
        }

    }
}
#endif

// MARK: - Preview

@available(iOS 14.0, macOS 11, *)
struct MultiLineTextInputView_Previews: PreviewProvider {
    @State private static var text: String = ""

    static var previews: some View {
        MultiLineTextInputView(
            field: InputField(
                label: "What is the speed you are getting?",
                submitLabel: "",
                type: .textSingleLine,
                isMandatory: true,
                placeholder: "Lorem ipsum dolor sit amet, consectetur adipiscing"),
            value: $text
        )
        .preferredColorScheme(.dark)
    }
}
