//
//  Created on 22.05.23.
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

import Foundation
import SwiftUI

import ComposableArchitecture
import Dependencies

import Domain
import Ergonomics
import HomeShared
import OrderedCollections
import ProtonCoreUIFoundations
import SharedViews
import Strings
import Theme
import VPNAppCore

public struct RecentsSectionView: View {
    let store: StoreOf<RecentsFeature>

    private func sectionTitleView(title: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .themeFont(.caption())
                .styled(.weak)
                .padding([.top, .horizontal], .themeSpacing12)
            Spacer()
        }
        .frame(maxWidth: Constants.maxHomeContentWidth)
    }

    private var recentsList: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                sectionTitleView(title: Localizable.homeRecentsRecentSection)
                DividedForEach(store.recentConnectionList) { item in
                    WithPerceptionTracking {
                        RecentRowItemView(
                            item: item,
                            isConnected: store.vpnConnectionStatus.spec == item.connection,
                            sendAction: { _ = store.send($0) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if (store.userTier ?? .freeTier).isFreeTier {
            sectionTitleView(title: Localizable.homeRecentsUpsellSection)
            UpsellCarousel(sendAction: { _ = store.send($0) })
        } else if !store.recentConnectionList.isEmpty {
            recentsList
                .frame(maxWidth: Constants.maxHomeContentWidth)
        } else {
            // EmptyView() causes the container view to be completely discarded by SwiftUI
            // and it won't invoke the task below (i.e. sending `watchConnectionStatus` to the store)
            Color.clear
                .frame(width: 0, height: 0)
                .hidden()
        }
    }

    public var body: some View {
        WithPerceptionTracking {
            content
                .task { store.send(.watchConnectionStatus) }
        }
    }
}

#if DEBUG && compiler(>=6)
    @available(iOS 18, *)
    #Preview("Recents", traits: .dependencies { $0.recentsStorage = .previewValue }) {
        let store: StoreOf<RecentsFeature> = .init(
            initialState: .init(),
            reducer: RecentsFeature.init
        )
        return ScrollView {
            RecentsSectionView(store: store)
        }
        .background(Color(.background, .normal))
    }

    @available(iOS 18, *)
    #Preview("No recents", traits: .dependencies { $0.recentsStorage = .withElements(array: []) }) {
        let store: StoreOf<RecentsFeature> = .init(
            initialState: .init(),
            reducer: RecentsFeature.init
        )
        return ScrollView {
            RecentsSectionView(store: store)
        }
        .background(Color(.background, .normal))
    }
#endif
