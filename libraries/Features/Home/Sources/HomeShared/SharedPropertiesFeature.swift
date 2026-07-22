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

import Announcement
import CommonNetworking
import ComposableArchitecture
import Connection
import Domain
import Ergonomics
import Foundation
import Persistence
import ProtonCoreFeatureFlags
import VPNAppCore
import WidgetKit

@Reducer
public struct SharedPropertiesFeature {
    @Dependency(\.logicalsClient) var logicalsClient
    @Dependency(\.serverRepository) var repository
    @Dependency(\.announcementManager) var announcementManager
    @Dependency(\.imagePrefetcher) var imagePrefetcher

    @Shared(.announcementBanner) var announcementBanner: Announcement?

    @ObservableState
    public struct State: Equatable {
        @Shared(.lastConnectionError) var lastConnectionError: ConnectionError?

        var userLocation: UserLocationFeature.State = .init()
        var review: ReviewFeature.State = .init()
    }

    public enum Action {
        case listen
        case userLocation(UserLocationFeature.Action)
        case review(ReviewFeature.Action)

        case connectionFailed(ConnectionError)
        case newAnnouncementBanner

        case refreshServerLoads(UserLocation)
    }

    private enum CancelId {
        case watchAnnouncementBanner
    }

    private var longLivingAnnouncementBannerEffect: Effect<Action> {
        .publisher {
            announcementManager.announcementsPublisher()
                .receive(on: UIScheduler.shared)
                .map { _ in Action.newAnnouncementBanner }
        }.cancellable(id: CancelId.watchAnnouncementBanner)
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.userLocation, action: \.userLocation) {
            UserLocationFeature()
        }
        Scope(state: \.review, action: \.review) {
            ReviewFeature()
        }

        Reduce { state, action in
            switch action {
            case .listen:
                return .merge(
                    .send(.userLocation(.listen)),
                    .send(.review(.listen)),
                    longLivingAnnouncementBannerEffect
                )

            case let .userLocation(.delegate(.userLocationChanged(location))):
                return .send(.refreshServerLoads(location))

            case let .refreshServerLoads(location):
                return .run { _ in
                    let loads = try await logicalsClient.fetchLoads(location: location)
                    log.debug("Fetched server loads", category: .api, metadata: ["serverCount": "\(loads.count)"])
                    repository.upsert(loads: loads)
                    NotificationCenter.default.post(ServerListUpdateNotification(data: .loads), object: nil)
                } catch: { error, _ in
                    log.error("Failed to update loads", category: .api, metadata: ["error": "\(error)"])
                }

            case .userLocation, .review:
                return .none

            case let .connectionFailed(error):
                state.$lastConnectionError.withLock { $0 = error }

                return .send(.review(.connectionFailed))

            case .newAnnouncementBanner:
                return .run { _ in
                    let urls = announcementManager.fetchCurrentAnnouncementsFromStorage().compactMap(\.prefetchableImage)
                    await imagePrefetcher.prefetchURLs(urls)
                    $announcementBanner.withLock { $0 = announcementManager.fetchCurrentOfferBannerFromStorage() }
                }
            }
        }
    }
}

#if DEBUG
    import Combine

    public extension LocationClient {
        static func jumping(every interval: TimeInterval = 1) -> some Publisher<UserLocation, Never> {
            Timer.publish(every: interval, on: .main, in: .default)
                .autoconnect()
                .map { _ in UserLocation.samples.randomElement()! }
        }
    }
#endif
