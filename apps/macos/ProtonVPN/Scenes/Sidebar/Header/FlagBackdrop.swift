//
//  Created on 11/08/2026 by Max Kupetskyi.
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

/// The flag of the connected country behind the header, or the plain background when disconnected.
///
/// Two gradients darken the flag, one from each side, so the text on top stays readable whatever the
/// flag looks like.
struct FlagBackdrop: View {
    let countryCode: String?

    var body: some View {
        Color(.background)
            .overlay {
                if let countryCode,
                   let flag: Image = AppTheme.Icon.flag(countryCode: countryCode, style: .large) {
                    flag
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .overlay {
                            LinearGradient(
                                colors: [Color(.background, .transparent), Color(.background)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                        .overlay {
                            LinearGradient(
                                colors: [Color(.background), Color(.background, .transparent)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        }
                }
            }
            .clipped()
    }
}
