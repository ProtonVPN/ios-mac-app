//
//  Created on 29/06/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import SDWebImageSwiftUI
import Strings
import SwiftUI
import Theme

public struct AnnouncementOfferView: View {
    let store: StoreOf<AnnouncementsFeature>

    public init(store: StoreOf<AnnouncementsFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.panel.panelMode() {
        case let .legacy(panel):
            AnnouncementDetailView(
                panel: panel,
                onAction: { store.send(.actionButtonTapped) },
                onClose: { store.send(.closeButtonTapped) }
            )
        case let .image(panel):
            AnnouncementOfferImageView(
                panel: panel,
                onAction: { store.send(.actionButtonTapped) },
                onClose: { store.send(.closeButtonTapped) }
            )
        case .none:
            // Nothing renderable — dismiss immediately.
            Color.clear.onAppear { store.send(.closeButtonTapped) }
        }
    }
}

struct AnnouncementOfferImageView: View {
    let panel: OfferPanel.ImagePanel
    let onAction: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: .themeSpacing16) {
                if let url = panel.fullScreenImage.firstURL {
                    WebImage(url: url)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(panel.fullScreenImage.alternativeText)
                }
                Button(panel.button.text ?? Localizable.ok, action: onAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.themeSpacing16)

            AnnouncementCloseButton(action: onClose)
                .padding(.themeSpacing16)
        }
        .background(Color(.background, .weak))
    }
}

struct AnnouncementCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Theme.Asset.dismissButton.swiftUIImage
                .resizable()
                .frame(.square(.themeSpacing24))
        }
        .buttonStyle(.plain)
    }
}
