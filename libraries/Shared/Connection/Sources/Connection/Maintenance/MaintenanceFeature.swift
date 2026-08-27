//
//  Created on 30/07/2026 by Max Kupetskyi.
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

import Clocks
import ComposableArchitecture
import CoreConnection
import Domain
import Foundation
import Sharing
import VPNAppCore

/// Polls the server we're connected to, and reconnects elsewhere when it's about to go into maintenance.
///
/// Only meaningful for a logged in user, so it's driven by the platform's signed in root feature rather than by app
/// launch.
@Reducer
public struct MaintenanceFeature {
    @Dependency(\.maintenanceChecker) private var maintenanceChecker
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.notificationManager) private var notificationManager
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.date) private var date
    @Dependency(\.withRandomNumberGenerator) private var withRandomNumberGenerator

    /// Spreads clients out so they don't all poll the API at the same moment.
    private static let jitterPercentage = 10

    /// Throttles the "server going on maintenance" notification so repeated detections don't spam the user.
    /// The reconnect still happens every time.
    private static let notificationThreshold: TimeInterval = 60 * 60 * 12

    @ObservableState
    public struct State: Equatable {
        /// The unjittered interval the running timer was started with.
        ///
        /// Feature flags are refreshed far more often than the maintenance interval changes, so without this the
        /// countdown would restart on every refresh and the check would rarely fire.
        var pollingInterval: Duration?

        /// When the user was last told a server is going into maintenance.
        var lastNotifiedAt: Date?

        @SharedReader(.featureFlags) var featureFlags: FeatureFlags
        @SharedReader(.maintenanceServerRefreshIntereval) var refreshIntervalInMinutes: Int

        public init() {}
    }

    public enum Action {
        /// Starts watching the configuration and polling. Send this once the user is signed in.
        case onStart
        /// Stops polling. Send this when the signed in session ends.
        case onStop
        /// The feature flags changed, so polling may need to start, stop, or change its interval.
        case configurationChanged
        case checkServer
        case serverIsGoingIntoMaintenance
    }

    private enum CancelID {
        case poll
        case configuration
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onStart:
                return .merge(
                    .send(.configurationChanged),
                    .publisher { [featureFlags = state.$featureFlags] in
                        featureFlags
                            .publisher
                            .dropFirst()
                            .receive(on: UIScheduler.shared)
                            .map { _ in Action.configurationChanged }
                    }
                    .cancellable(id: CancelID.configuration)
                )

            case .onStop:
                state.pollingInterval = nil
                return .merge(.cancel(id: CancelID.poll), .cancel(id: CancelID.configuration))

            case .configurationChanged:
                guard state.featureFlags.serverRefresh else {
                    state.pollingInterval = nil
                    return .cancel(id: CancelID.poll)
                }

                let interval = Duration.seconds(state.refreshIntervalInMinutes * 60)
                guard interval > .zero else {
                    // A non-positive interval means check once, without scheduling anything
                    state.pollingInterval = nil
                    return .merge(.cancel(id: CancelID.poll), .send(.checkServer))
                }
                guard state.pollingInterval != interval else {
                    return .none // Already polling at this interval, leave the countdown alone
                }

                state.pollingInterval = interval
                return .run { [interval = jittered(interval)] send in
                    for await _ in clock.timer(interval: interval) {
                        await send(.checkServer)
                    }
                }
                .cancellable(id: CancelID.poll, cancelInFlight: true)

            case .checkServer:
                return .run { send in
                    guard try await maintenanceChecker.isCurrentServerUnderMaintenance() else { return }
                    await send(.serverIsGoingIntoMaintenance)
                } catch: { error, _ in
                    log.error(
                        "Checking for server maintenance failed",
                        category: .app,
                        metadata: ["error": "\(error)"]
                    )
                }

            case .serverIsGoingIntoMaintenance:
                log.info(
                    "The currently connected server will be going to maintenance soon, reconnecting",
                    category: .connectionConnect
                )

                let now = date.now
                let shouldNotify = state.lastNotifiedAt
                    .map { now.timeIntervalSince($0) > Self.notificationThreshold } ?? true
                if shouldNotify {
                    state.lastNotifiedAt = now
                }

                return .run { [shouldNotify] _ in
                    if shouldNotify {
                        notificationManager.displayServerGoingOnMaintenance()
                    }
                    // Prefer the user's saved Quick Connect profile, otherwise fall back to fastest. Deliberately not
                    // the last connection intent, which would reconnect to the maintenance server.
                    connectionCommandClient.quickConnect(trigger: .auto)
                }
            }
        }
    }

    /// Offsets the interval by up to ±``jitterPercentage``, so clients don't poll in lockstep.
    private func jittered(_ interval: Duration) -> Duration {
        let percentage = withRandomNumberGenerator { generator in
            Int.random(in: -Self.jitterPercentage ... Self.jitterPercentage, using: &generator)
        }
        let seconds = Double(interval.components.seconds)
        return .seconds(seconds + seconds * Double(percentage) / 100)
    }
}
