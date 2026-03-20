//
//  Created on 09/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

struct UpsellPrimaryActionButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    @State private var didPushPointingCursor = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .themeFont(.title2())
                .foregroundStyle(Color(.text))
                .padding(.horizontal, .themeSpacing24)
                .frame(minHeight: 46)
                .background(isHovered ? Color(.icon, [.interactive, .hovered]) : Color(.icon, .interactive))
                .clipShape(RoundedRectangle(cornerRadius: .themeRadius8))
                .contentShape(RoundedRectangle(cornerRadius: .themeRadius8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering, !didPushPointingCursor {
                NSCursor.pointingHand.push()
                didPushPointingCursor = true
            } else if !hovering, didPushPointingCursor {
                NSCursor.pop()
                didPushPointingCursor = false
            }
        }
    }
}
