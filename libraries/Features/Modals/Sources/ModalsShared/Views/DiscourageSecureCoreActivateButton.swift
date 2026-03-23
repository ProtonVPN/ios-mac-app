//
//  Created on 17/04/2026 by Max Kupetskyi.
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

import Strings
import SwiftUI

struct DiscourageSecureCoreActivateButton: View {
    let action: () -> Void

    #if os(macOS)
        @State private var didPushPointingCursor = false
    #endif

    var body: some View {
        Button {
            action()
        } label: {
            Text(Localizable.modalsDiscourageSecureCoreActivate)
            #if os(iOS)
                .themeFont(.body1(.regular))
                .frame(maxWidth: .infinity)
            #elseif os(macOS)
                .themeFont(.title3())
            #endif
                .foregroundStyle(Color(.text))
                .padding(.vertical, .themeSpacing12)
        }
        .background(Color(.background, .interactive))
        .clipShape(RoundedRectangle(cornerRadius: .themeRadius8))
        #if os(macOS)
            .onHover { hovering in
                if hovering, !didPushPointingCursor {
                    NSCursor.pointingHand.push()
                    didPushPointingCursor = true
                } else if !hovering, didPushPointingCursor {
                    NSCursor.pop()
                    didPushPointingCursor = false
                }
            }
        #endif
    }
}
