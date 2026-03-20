//
//  Created on 19/03/2026 by Max Kupetskyi.
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
import Domain
import Foundation
import NetShield
import SwiftUI
import Theme

@Reducer
struct NetShieldQuickSettingFeature {
    @ObservableState
    struct State: Equatable {
        var isSelected: Bool
        var type: NetShieldType
        var isVisible: Bool
        var isStatsEnabled: Bool
        var connectionInfo: ConnectionInfo
        var stats: NetShieldModel

        var icon: Image {
            switch type {
            case .off:
                Theme.Asset.Icons.shield.swiftUIImage
            case .level1:
                Theme.Asset.Icons.shieldHalfFilled.swiftUIImage
            case .level2:
                Theme.Asset.Icons.shieldFilled.swiftUIImage
            @unknown default:
                Theme.Asset.Icons.shield.swiftUIImage
            }
        }

        let accessibilityIdentifier = "NetShieldButton"

        var badgeVisible: Bool {
            guard isStatsEnabled, type == .level2 else { return false }
            guard blockedAdsAndTrackersCount > 0 else { return false }
            return connectionInfo.isConnected && isVisible
        }

        var badgeModel: NetShieldModel {
            guard type == .level2 else { return .zero(enabled: false) }
            return stats
        }

        var blockedAdsAndTrackersCount: Int {
            badgeModel.adsCount + badgeModel.trackersCount
        }

        var badgeText: String {
            blockedAdsAndTrackersCount >= 99 ? "99+" : "\(blockedAdsAndTrackersCount)"
        }

        var isEnabled: Bool {
            type != .off
        }
    }

    enum Action {
        case startObserving
        case updateNetShield
        case netShieldStatsUpdated(NetShieldModel)

        case buttonTapped
        case delegate(Delegate)

        enum Delegate {
            case tapped(QuickSettingType)
        }
    }

    @Dependency(\.propertiesManager) var propertiesManager
    @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider

    private enum CancelID { case netShieldObservations }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startObserving:
                state.type = netShieldPropertyProvider.getNetShieldType()
                state.isVisible = propertiesManager.featureFlags.netShield
                state.isStatsEnabled = propertiesManager.featureFlags.netShieldStats
                return .merge(
                    .run { send in
                        let stream: AsyncStream<NetShieldModel> = NotificationCenter.default.notifications(NetShieldStatsNotification.self)
                        for await stats in stream {
                            await send(.netShieldStatsUpdated(stats))
                        }
                    },
                    .run { send in
                        for await _ in netShieldPropertyProvider.netShieldTypeStream() {
                            await send(.updateNetShield)
                        }
                    }
                ).cancellable(id: CancelID.netShieldObservations)
            case .updateNetShield:
                state.type = netShieldPropertyProvider.getNetShieldType()
                state.isVisible = propertiesManager.featureFlags.netShield
                return .none
            case let .netShieldStatsUpdated(stats):
                state.stats = stats
                return .none
            case .buttonTapped:
                return .send(.delegate(.tapped(.netShieldDisplay)))
            case .delegate:
                return .none
            }
        }
    }
}
