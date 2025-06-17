//
//  Created on 2025-05-29 by Pawel Jurczyk.
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

import ProtonCoreUIFoundations
import SwiftUI
import Theme

extension View {
    func clearButton(text: Binding<String>) -> some View {
        modifier(ClearButton(text: text))
    }
}

struct ClearButton: ViewModifier {
    @Binding var text: String

    public func body(content: Content) -> some View {
        HStack(spacing: .themeSpacing8) {
            content
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    IconProvider.crossCircleFilled.swiftUIImage
                        .resizable()
                        .foregroundStyle(Color(.text, .weak))
                        .frame(.square(.themeSpacing12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
