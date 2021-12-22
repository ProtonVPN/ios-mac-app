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
import UIKit

/// Multiline text input styled for usage in bug report form.
@available(iOS 14.0, *)
struct MultiLineTextInputView: View {
    var field: InputField
    @Binding var value: String
    @Environment(\.colors) var colors: Colors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(field.label)
                .font(.system(size: 13))
                .padding(.bottom, 8)
            
            ZStack(alignment: .topLeading) {
                if value.isEmpty {
                    Text(field.placeholder ?? "")
                        .font(.system(size: 17))
                        .foregroundColor(colors.textSecondary)
                }
                TextView(text: $value, fontSize: 17)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(colors.backgroundSecondary)
            .cornerRadius(8)
            
        }
        .padding(.horizontal)
    }
}

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

// MARK: - Preview

@available(iOS 14.0, *)
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
