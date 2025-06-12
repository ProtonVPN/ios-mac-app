//
//  Created on 2025-04-24 by Pawel Jurczyk.
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
import Lottie

import Strings

public struct WidgetSettingsView: View {
    private static let lottieAnimationViewHeight: CGFloat = 192.0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .themeSpacing24) {
                LottieView(animation: .widgetAdoption)
                    .playing(loopMode: .loop)
                    .frame(height: Self.lottieAnimationViewHeight)
                    .background(Color(.background))
                    .clipShape(RoundedRectangle(cornerRadius: .themeRadius16))

                WidgetInstructionsView(backgroundColor: Color(.background))
            }
            .padding(.themeSpacing16)
        }
        .background(Color(.background, .strong))
    }
}
