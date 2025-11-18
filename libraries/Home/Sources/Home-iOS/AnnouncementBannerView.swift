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

import ComposableArchitecture
import SDWebImageSwiftUI

import Announcement
import HomeShared
import Strings
import Theme

struct AnnouncementBannerView: View {
    let store: StoreOf<AnnouncementBannerFeature>

    public init(store: StoreOf<AnnouncementBannerFeature>) {
        self.store = store
    }

    private let colors = [
        Theme.Asset.offerBannerGradientRight.swiftUIColor,
        Theme.Asset.offerBannerGradientLeft.swiftUIColor,
    ]

    private static let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    private func timeLeftString(endTime: Date) -> String? {
        let timeLeft = endTime.timeIntervalSinceNow
        guard timeLeft >= 0 else { return nil }
        let string = Self.relativeDateTimeFormatter.localizedString(fromTimeInterval: timeLeft)
        return Localizable.offerEnding(string)
    }

    @State private var showBanner = false

    var body: some View {
        if case let .banner(model) = store.state {
            content(model: model)
        } else {
            EmptyView()
        }
    }

    private func content(model: AnnouncementBannerFeature.State.Model) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                store.send(.didTapBanner)
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    WebImage(url: model.imageURL)
                        .resizable().scaledToFit()
                    if model.showCountdown, let timeLeft = timeLeftString(endTime: model.endTime) {
                        Text(timeLeft)
                            .themeFont(.caption(emphasised: false))
                            .foregroundStyle(Color(.text, .weak))
                    }
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
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .cornerRadius(.themeRadius8)
            }
            Button {
                store.send(.didTapDismiss, animation: .default)
            } label: {
                Theme.Asset.dismissButton.swiftUIImage
            }
            .buttonStyle(StaticButtonStyle())
            .offset(x: 12, y: -12)
        }
        .frame(maxHeight: showBanner ? .infinity : 0)
        .opacity(showBanner ? 1 : 0)
        .task {
            @Dependency(\.imagePrefetcher) var imagePrefetcher
            if await imagePrefetcher.containsImageForKey(model.imageURL.absoluteString) {
                showBanner = true
                return
            }
            await imagePrefetcher.prefetchURLs([model.imageURL])
            showBanner = await imagePrefetcher.containsImageForKey(model.imageURL.absoluteString)
        }
    }
}

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
