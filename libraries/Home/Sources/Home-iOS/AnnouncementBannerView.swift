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
import Announcement

public struct AnnouncementBannerView: View {

    let offerBanner: OfferBannerViewModel

    let colors = [
        Theme.Asset.offerBannerGradientRight.swiftUIColor,
        Theme.Asset.offerBannerGradientLeft.swiftUIColor
    ]

    public init(announcement: Announcement) {
        self.announcement = announcement
    }

    public var body: some View {
        if let url = URL(string: offerBanner.imageURL) {
            ZStack(alignment: .topTrailing) {
                Link(destination: url) {
                    VStack(alignment: .leading, spacing: 0) {
                        AsyncImage(url: URL(string: imageURLString)) {
                            $0.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        Text(offerBanner.timeLeftString())
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

#if DEBUG
@available(iOS 17, *)
#Preview(traits: .sizeThatFitsLayout) {
    let actionURLString = "https://account.volta.proton.black/lite?action=subscribe-account&coupon=TRYVPNPLUS2024&currency=CHF&disablePlanSelection=1&fullscreen=auto&hideClose=1&plan=vpn2024&redirect=protonvpn%3A%2F%2Frefresh-account&ref=ios-apr-1-modal&start=checkout"
    let imageURLString = "https://download.protonvpn.net/download/resources/promo/free-to-paid/en-mobile-banner@2x.png"
    return AnnouncementBannerView(actionURLString: actionURLString,
                                  imageURLString: imageURLString)
    .padding()
    .preferredColorScheme(.dark)
}
#endif
