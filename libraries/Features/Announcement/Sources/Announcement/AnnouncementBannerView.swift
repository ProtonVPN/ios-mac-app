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

import ComposableArchitecture
import SDWebImageSwiftUI
import Strings
import SwiftUI
import Theme

public struct AnnouncementBannerView: View {
    let store: StoreOf<AnnouncementBannerFeature>

    public init(store: StoreOf<AnnouncementBannerFeature>) {
        self.store = store
    }

    #if DEBUG
        init(store: StoreOf<AnnouncementBannerFeature>, revealed: Bool) {
            self.store = store
            self._showBanner = State(initialValue: revealed)
        }
    #endif

    private let colors = [
        Theme.Asset.offerBannerGradientRight.swiftUIColor,
        Theme.Asset.offerBannerGradientLeft.swiftUIColor,
    ]

    #if os(iOS)
        private static let cornerRadius: CGFloat = .themeRadius8
    #else
        private static let cornerRadius: CGFloat = .themeRadius12
    #endif

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

    public var body: some View {
        if case let .banner(model) = store.state {
            content(model: model)
        }
    }

    private func content(model: AnnouncementBannerFeature.State.Model) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                store.send(.didTapBanner)
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    WebImage(url: model.imageURL)
                        .resizable()
                        .scaledToFit()
                    if model.showCountdown, let timeLeft = timeLeftString(endTime: model.endTime) {
                        // `caption` typography only exists on UIKit; macOS keeps the legacy default font.
                        #if os(iOS)
                            Text(timeLeft)
                                .themeFont(.caption(emphasised: false))
                                .foregroundStyle(Color(.text, .weak))
                        #else
                            Text(timeLeft)
                                .foregroundStyle(Color(.text, .weak))
                        #endif
                    }
                }
                .padding(.horizontal, .themeSpacing16)
                .padding(.vertical, .themeSpacing12)
                .background(Color(.background, .weak))
                .overlay(
                    RoundedRectangle(cornerRadius: Self.cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: colors,
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .clipShape(.rect(cornerRadius: Self.cornerRadius))
            }
            .buttonStyle(.plain)
            dismissButton
        }
        .frame(maxHeight: showBanner ? .infinity : 0)
        .opacity(showBanner ? 1 : 0)
        .task {
            if showBanner {
                return
            }
            @Dependency(\.imagePrefetcher) var imagePrefetcher
            if await imagePrefetcher.containsImageForKey(model.imageURL.absoluteString) {
                showBanner = true
                return
            }
            await imagePrefetcher.prefetchURLs([model.imageURL])
            showBanner = await imagePrefetcher.containsImageForKey(model.imageURL.absoluteString)
        }
    }

    private var dismissButton: some View {
        Button {
            store.send(.didTapDismiss, animation: .default)
        } label: {
            #if os(iOS)
                Theme.Asset.dismissButton.swiftUIImage
            #else
                Theme.Asset.dismissButton.swiftUIImage
                    .resizable()
                    .frame(.square(.themeSpacing32))
            #endif
        }
        .buttonStyle(StaticButtonStyle())
        #if os(iOS)
            .offset(x: .themeSpacing12, y: -.themeSpacing12)
        #else
            .offset(x: .themeSpacing16, y: -.themeSpacing16)
        #endif
    }
}

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
