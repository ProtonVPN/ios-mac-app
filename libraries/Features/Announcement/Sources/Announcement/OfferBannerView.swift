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

import Dependencies
import SDWebImage
import SwiftUI
import Theme

public struct OfferBannerView: View {
    let viewModel: OfferBannerViewModel

    @State private var timeRemainingText: String?
    @State private var timerTask: Task<Void, Error>?
    @State private var offerImage: Image?

    var onDismiss: () -> Void

    public init(viewModel: OfferBannerViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedBackgroundViewSwiftUI {
                VStack(alignment: .leading, spacing: 0) {
                    if let offerImage {
                        offerImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }

                    if viewModel.showCountdown, let timeRemainingText {
                        Text(timeRemainingText)
                            .foregroundColor(Color(.text, .weak))
                    }
                }
                .padding(.horizontal, .themeSpacing16)
                .padding(.vertical, .themeSpacing12)
            }
            .padding(.top, .themeSpacing16)
            .padding(.bottom, .themeSpacing8)

            Button(action: {
                timerTask?.cancel()
                timerTask = nil
                viewModel.dismiss()
                onDismiss()
            }) {
                Theme.Asset.dismissButton.swiftUIImage
                    .resizable()
                    .frame(.square(.themeSpacing32))
            }
            .buttonStyle(.plain)
            .offset(x: .themeSpacing16)
        }
        .onAppear {
            loadImage()
            updateTimeRemaining()
            timerTask = viewModel.createTimer(updateTimeRemaining: updateTimeRemaining)
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
        }
        .onTapGesture {
            Task {
                @Dependency(\.sessionService) var sessionService
                await viewModel.action(sessionService)
            }
        }
    }

    private func loadImage() {
        if let cachedImage = SDImageCache.shared.imageFromCache(forKey: viewModel.imageURL.absoluteString) {
            offerImage = cachedImage.swiftUIImage
            return
        }

        SDWebImageDownloader.shared.downloadImage(with: viewModel.imageURL) { image, _, _, _ in
            if let image {
                SDImageCache.shared.store(image, forKey: viewModel.imageURL.absoluteString, completion: nil)
                offerImage = image.swiftUIImage
            }
        }
    }

    private func updateTimeRemaining() {
        guard let text = viewModel.timeLeftString() else {
            timerTask?.cancel()
            timerTask = nil
            viewModel.dismiss()
            return
        }
        timeRemainingText = text
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
        OfferBannerView(viewModel: OfferBannerViewModel.withCountdown) {}
            .preferredColorScheme(.dark)
    }

    #Preview("Without Countdown") {
        OfferBannerView(viewModel: OfferBannerViewModel.withoutCountdown) {}
            .preferredColorScheme(.dark)
    }

    #Preview("Expiring Soon") {
        OfferBannerView(viewModel: OfferBannerViewModel.expiringSoon) {}
            .preferredColorScheme(.dark)
    }

    #Preview("Long Duration") {
        OfferBannerView(viewModel: OfferBannerViewModel.longDuration) {}
            .preferredColorScheme(.dark)
    }
#endif
