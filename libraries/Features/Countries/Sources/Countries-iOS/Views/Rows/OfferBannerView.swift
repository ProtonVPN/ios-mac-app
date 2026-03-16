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

import ComposableArchitecture
import CountriesShared
import SwiftUI
import Theme

struct OfferBannerView: View {
    let store: StoreOf<OfferBannerFeature>

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedBackgroundViewSwiftUI {
                VStack(alignment: .leading, spacing: 0) {
                    AsyncImage(url: store.imageURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .empty, .failure:
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }

                    if store.showCountdown, let timeRemainingText = store.timeLeftString {
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
                store.send(.dismissTapped)
            }) {
                Theme.Asset.dismissButton.swiftUIImage
                    .resizable()
                    .frame(width: 42, height: 42)
            }
            .offset(x: 22, y: -22)
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onTapGesture {
            store.send(.buttonTapped)
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
            store: Store(
                initialState: OfferBannerFeature.State(
                    imageURL: URL(string: "https://example.com/offer.png")!,
                    endTime: Date().addingTimeInterval(60 * 60 * 24 * 2),
                    showCountdown: true,
                    buttonURL: URL(string: "https://protonvpn.com")!,
                    offerReference: nil,
                    timeLeftString: "2 days left"
                )
            ) {
                OfferBannerFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Without Countdown") {
        OfferBannerView(
            store: Store(
                initialState: OfferBannerFeature.State(
                    imageURL: URL(string: "https://example.com/offer.png")!,
                    endTime: Date().addingTimeInterval(60 * 60 * 24 * 2),
                    showCountdown: false,
                    buttonURL: URL(string: "https://protonvpn.com")!,
                    offerReference: nil,
                    timeLeftString: nil
                )
            ) {
                OfferBannerFeature()
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
