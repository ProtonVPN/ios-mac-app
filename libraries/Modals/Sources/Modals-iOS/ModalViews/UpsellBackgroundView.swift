//
//  Created on 13/12/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Theme

struct UpsellBackgroundView<Content>: View where Content: View {
    let showGradient: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            if showGradient {
                VStack(spacing: 0) {
                    gradient
                    Spacer()
                }
                .ignoresSafeArea()
            }
            content
        }
    }

    var gradient: some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return Color.clear
            .aspectRatio(isPad ? 2 : 1, contentMode: .fit)
            .background(
                ZStack {
                    let gradient = Gradient(colors: [Asset.upsellGradientTop.swiftUIColor,
                                                     Asset.upsellGradientBottom.swiftUIColor])
                    LinearGradient(gradient: gradient,
                                   startPoint: .top,
                                   endPoint: .bottom)
                    .opacity(0.4)
                    let fadingGradient = Gradient(colors: [.clear, Color(.background)])
                    LinearGradient(gradient: fadingGradient,
                                   startPoint: .top,
                                   endPoint: .bottom)
                }
            )
    }
}
