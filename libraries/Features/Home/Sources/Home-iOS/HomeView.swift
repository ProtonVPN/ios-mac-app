//
//  Created on 25/04/2023.
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

import Announcement
import Combine
import ComposableArchitecture
import ConnectionDetails
import Dependencies
import Domain
import Ergonomics
import HomeShared
import Modals
import ModalsShared
import Payments
import PCAP
import SharedViews
import Strings
import SwiftUI
import Theme
import VPNAppCore

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    private enum Dimensions {
        static let horizontalPadding: CGFloat = .themeSpacing16
    }

    public var body: some View {
        contentWithSheets
            .onAppear { store.send(.onAppear) }
            .onDisappear { store.send(.onDisappear) }
    }

    private var contentWithSheets: some View {
        content
            .sessionCapturedSheet(store: $store)
            .connectionDetailsSheet(store: $store)
            .changeServerSheet(store: $store)
            .defaultConnectionSheet(store: $store)
            .whatsNewSheet(store: $store)
            .freeConnectionsInfoSheet(store: $store)
            .paymentsSheet(store: $store)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HomeConnectionCardView(store: store.scope(state: \.connectionCard, action: \.connectionCard))
                        .padding(.horizontal, Dimensions.horizontalPadding)
                        .padding(.bottom, .themeSpacing12)
                        .frame(maxWidth: Theme.Constants.maxHomeContentWidth)
                    AnnouncementBannerView(store: store.scope(state: \.announcementBanner, action: \.announcementBanner))
                        .padding(.horizontal, Dimensions.horizontalPadding)
                        .padding(.bottom, .themeSpacing8)
                        .padding(.top, .themeSpacing16)
                        .frame(maxWidth: Theme.Constants.maxAnnouncementBannerWidth)
                }

                RecentsSectionView(store: store.scope(state: \.recents, action: \.recents))
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.background))
        .task {
            @Dependency(\.announcementManager) var announcementManager
            for await _ in announcementManager.announcementsPublisher().values {
                await MainActor.run {
                    AnnouncementOfferCoordinator().presentOneTimeAnnouncementIfNeeded()
                }
            }
        }
    }
}

// This extension helps the compiler to typecheck in a reasonable amount of time
private extension View {
    func connectionDetailsSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(
            item: store.scope(state: \.destination?.connectionDetails, action: \.destination.connectionDetails)
        ) { store in
            ConnectionScreenView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    func sessionCapturedSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(
            item: store.scope(state: \.destination?.sessionCaptured, action: \.destination.sessionCaptured)
        ) { store in
            SessionCapturedSheetView(store: store)
        }
    }

    func changeServerSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(item: store.scope(state: \.destination?.changeServer, action: \.destination.changeServer), onDismiss: {
            store.wrappedValue.send(.didDismissChangeServer)
        }) { store in
            ChangeServerModal(store: store)
        }
    }

    func defaultConnectionSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(
            item: store.scope(state: \.destination?.defaultConnection, action: \.destination.defaultConnection)
        ) { store in
            DefaultConnectionSheet(store: store)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
    }

    func whatsNewSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(
            item: store.scope(state: \.destination?.whatsNew, action: \.destination.whatsNew)
        ) { store in
            WhatsNewViewContainer(store: store)
        }
    }

    func freeConnectionsInfoSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(item: store.scope(state: \.destination?.freeConnectionsInfo, action: \.destination.freeConnectionsInfo)) { store in
            FreeConnectionsView(store: store)
        }
    }

    func paymentsSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        fullScreenCover(item: store.scope(state: \.destination?.payments, action: \.destination.payments)) { store in
            PaymentsMainView(store: store)
        }
    }
}

#if DEBUG && compiler(>=6)
    @available(iOS 18, *)
    #Preview {
        HomeView(store: .init(initialState: .init(), reducer: {
            HomeFeature()
        }))
    }
#endif
