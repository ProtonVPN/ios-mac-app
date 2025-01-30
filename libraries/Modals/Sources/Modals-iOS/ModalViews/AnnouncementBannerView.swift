//
//  Created on 2025-01-30.
//
//  Copyright (c) 2025 Proton AG
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
//import Strings
//import ProtonCoreUIFoundations
//import Modals

struct AnnouncementBannerView: View {

    let actionURLString: String
    let imageURLString: String

    let colors = [
        Theme.Asset.offerBannerGradientRight.swiftUIColor,
        Theme.Asset.offerBannerGradientLeft.swiftUIColor
    ]

    var body: some View {
        if let url = URL(string: actionURLString) {
            ZStack(alignment: .topTrailing) {
                Link(destination: url) {
                    VStack(alignment: .leading) {
                        AsyncImage(url: URL(string: imageURLString)) {
                            $0.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        Text("6 days 22 hours left")
                            .themeFont(.caption(emphasised: false))
                            .foregroundStyle(Color(.text, .weak))
                    }
                    .padding(.horizontal, .themeSpacing16)
                    .padding(.vertical, .themeSpacing12)
                    .background(Color(.background, .weak))
                    .overlay(
                        RoundedRectangle(cornerRadius: .themeRadius8)
                            .stroke(
                                LinearGradient(
                                    colors: colors,
                                    startPoint: .leading,
                                    endPoint: .trailing),
                                lineWidth: 1)
                    )
                    .cornerRadius(.themeRadius8)
                }
                Button {
                    print("close")
                } label: {
                    Theme.Asset.dismissButton.swiftUIImage
                }
                .buttonStyle(StaticButtonStyle())
                .offset(x: 12, y: -12)
            }
        }
    }
}

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
