//
//  Created on 23/12/2025 by Max Kupetskyi.
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

import CountriesShared
import SDWebImage
import SwiftUI
import Theme

struct OfferBannerView: View {
    let imageURL: URL
    let showCountdown: Bool

    @State private var timeRemainingText: String = "2 days 5 hours left"
    @State private var offerImage: ImageAsset.Image?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedBackgroundViewSwiftUI {
                VStack(alignment: .leading, spacing: 0) {
                    if let offerImage {
                        offerImage.swiftUIImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }

                    if showCountdown {
                        Text(timeRemainingText)
                            .themeFont(.body2(emphasised: false))
                            .foregroundColor(Color(.text, .weak))
                    }
                }
                .padding(.horizontal, .themeSpacing16)
                .padding(.vertical, .themeSpacing12)
            }
            .padding(.top, .themeSpacing16)
            .padding(.bottom, .themeSpacing8)

            Button(action: {
                print("Offer banner dismissed")
            }) {
                Theme.Asset.dismissButton.swiftUIImage
                    .resizable()
                    .frame(width: 42, height: 42)
            }
            .offset(x: 22, y: -22)
        }
        .onAppear {
            loadImage()
        }
        .onTapGesture {
            print("Offer banner tapped")
        }
    }

    private func loadImage() {
        if let cachedImage = SDImageCache.shared.imageFromCache(forKey: imageURL.absoluteString) {
            offerImage = cachedImage
            return
        }

        SDWebImageDownloader.shared.downloadImage(with: imageURL) { image, _, _, _ in
            if let image {
                SDImageCache.shared.store(image, forKey: imageURL.absoluteString, completion: nil)
                offerImage = image
            }
        }
    }
}

struct RoundedBackgroundViewSwiftUI<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color(.background, .weak))
            .cornerRadius(.themeRadius12)
            .overlay(
                RoundedRectangle(cornerRadius: .themeRadius12)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(Theme.Asset.offerBannerGradientLeft.color),
                                Color(Theme.Asset.offerBannerGradientRight.color),
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

#if DEBUG
    #Preview("With Countdown") {
        OfferBannerView(
            imageURL: URL(string: "https://example.com/offer.png")!,
            showCountdown: true
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Without Countdown") {
        OfferBannerView(
            imageURL: URL(string: "https://example.com/offer.png")!,
            showCountdown: false
        )
        .preferredColorScheme(.dark)
    }
#endif
