//
//  Created on 25/09/2024.
//
//  Copyright (c) 2024 Proton AG
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

import ComposableArchitecture

import ProtonCoreFeatureFlags

import CommonNetworking
import Connection
import Ergonomics
import Persistence
import Announcement
import Domain
import VPNAppCore

@Reducer
public struct SharedPropertiesFeature {
    @Dependency(\.logicalsClient) var logicalsClient
    @Dependency(\.serverRepository) var repository

    @ObservableState
    public struct State: Equatable {
        @Shared(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
        @Shared(.connectionState) var connectionState: ConnectionState
        @Shared(.announcementBanner) var announcementBanner: Announcement?

        var userLocation: UserLocationFeature.State = .init()
    }

    @CasePathable
    public enum Action {
        case listen
        case userLocation(UserLocationFeature.Action)
        // TODO: Rename those two actions below (& others if necessary) (VPNAPPL-2678)
        case newConnectionStatus(VPNConnectionStatus)
        case newConnectionState(ConnectionState)
        case newAnnouncementBanner(Notification)

        case refreshServerLoads(UserLocation)
    }

    private enum CancelId {
        case watchConnectionStatus
        case watchAnnouncementBanner
    }

    private static let connectionStatusStream: AsyncStream<VPNConnectionStatus> = {
        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.useConnectionFeature) {
            return Dependency(\.connectionBridge).wrappedValue.statusStream()
        } else {
            return Dependency(\.vpnConnectionStatusPublisher).wrappedValue()
        }
    }()

    private let longLivingConnectionStatusEffect: Effect<Action> = .run { @MainActor send in
        if !FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.useConnectionFeature) {
            // Legacy connection status stream does not yield an initial value
            let initialConnectionStatus = await Dependency(\.vpnConnectionStatus).wrappedValue()
            send(.newConnectionStatus(initialConnectionStatus))
        }

        let actionStream = Self.connectionStatusStream.map { Action.newConnectionStatus($0) }

        for await value in actionStream {
            send(value)
        }
    }
    .cancellable(id: CancelId.watchConnectionStatus)

    private let longLivingAnnouncementBannerEffect: Effect<Action> = .publisher {
        AppEvent.announcementStorageContent
            .publisher
            .receive(on: UIScheduler.shared)
            .map(Action.newAnnouncementBanner)
    }.cancellable(id: CancelId.watchAnnouncementBanner)

    public var body: some Reducer<State, Action> {
        Scope(state: \.userLocation, action: \.userLocation) {
            UserLocationFeature()
        }
        Reduce { state, action in
            switch action {
            case .listen:
                return .merge(
                    .send(.userLocation(.listen)),
                    longLivingConnectionStatusEffect,
                    longLivingAnnouncementBannerEffect
                )

            case .userLocation(.delegate(.userLocationChanged(let location))):
                return .send(.refreshServerLoads(location))

            case .refreshServerLoads(let location):
                return .run { send in
                    let loads = try await logicalsClient.fetchLoads(location: location)
                    log.debug("Fetched server loads", category: .api, metadata: ["serverCount": "\(loads.count)"])
                    repository.upsert(loads: loads)
                } catch: { error, _ in
                    log.error("Failed to update loads", category: .api, metadata: ["error": "\(error)"])
                }

            case .userLocation(_):
                return .none

            case .newConnectionStatus(let newValue):
                state.$vpnConnectionStatus.withLock { $0 = newValue }
                return .none

            case .newConnectionState(let newValue):
                state.$connectionState.withLock { $0 = newValue }
                if newValue.is(\.disconnected) {
                    // User location will be fetched if it hasn't already been done recently
                    // e.g. if we were connected while the long living effect timer was ticking.
                    return .send(.userLocation(.fetchUserLocation))
                }
                return .none
            case .newAnnouncementBanner:
                @Dependency(\.announcementManager) var announcementManager
                state.$announcementBanner.withLock { $0 = announcementManager.fetchCurrentOfferBannerFromStorage() }
                return .none
            }
        }
    }
}

#if DEBUG
import Combine

extension LocationClient {
    public static func jumping(every interval: TimeInterval = 1) -> some Publisher<UserLocation, Never> {
        Timer.publish(every: interval, on: .main, in: .default)
            .autoconnect()
            .map { _ in UserLocation.samples.randomElement()! }
    }
}
#endif
