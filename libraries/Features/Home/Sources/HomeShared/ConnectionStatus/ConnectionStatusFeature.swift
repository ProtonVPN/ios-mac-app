//
//  Created on 09/06/2023.
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

import ComposableArchitecture
import Connection
import Domain
import Ergonomics
import ExtensionSync
import IPCErgonomics
import Localization
import NetShield
import SwiftUI
import VPNAppCore

@Reducer
public struct ConnectionStatusFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.protectionState) package var protectionState: ProtectionState
        @SharedReader(.userLocation) package var userLocation: StoredUserLocation?
        @SharedReader(.connectionState) package var connectionState: ConnectionState

        package var connectionStatusBanner: ConnectionStatusBannerFeature.State = .init()

        /// The unmasked `.protecting` state that started the current masking animation, or `nil`
        /// when no masking animation is in flight.
        ///
        /// Distinct `ConnectionState` values can map to the same `ProtectionState` (e.g.
        /// `.connecting(intent:tunnelActive:)` fires once with an unresolved and once with a
        /// resolved intent, both mapping to the same `.protecting(country:ip:)`), and
        /// re-subscribing to the publisher replays the current value. Comparing incoming
        /// `.protecting` states against this value deduplicates them so the masking animation
        /// isn't restarted — the shared `protectionState` can't be used for that comparison
        /// because the mask ticks progressively mutate it.
        var startingProtectionState: ProtectionState?

        public init() {}
    }

    public enum Action: Equatable {
        case startLocationMasking
        case maskLocationTick

        case watchConnectionStatus
        case newConnectionState(ConnectionState)
        case newProtectionState(ProtectionState)

        /// Not currently sent by anyone: the view's `.task` modifier owns the effect lifetime and
        /// cancels everything (including the mask timer, transitively) on disappear.
        case tearDown

        case connectionStatusBanner(ConnectionStatusBannerFeature.Action)
        case delegate(Delegate)
    }

    public enum Delegate: Equatable {
        case upsellTapped(ConnectionStatusBannerFeature.UpsellMode)
    }

    public init() {}

    private static let maskTickTimerDuration: Duration = .milliseconds(50)

    private enum IDs {
        case watchConnectionStatus
        case maskLocationTimer
    }

    @Dependency(\.continuousClock) private var clock
    @Dependency(\.countryNameProvider) private var countryNameProvider
    @Dependency(\.withRandomNumberGenerator) private var withRandomNumberGenerator

    public var body: some Reducer<State, Action> {
        Scope(state: \.connectionStatusBanner, action: \.connectionStatusBanner) {
            ConnectionStatusBannerFeature()
        }

        Reduce { state, action in
            switch action {
            case .startLocationMasking:
                return .run { send in
                    for await _ in clock.timer(interval: Self.maskTickTimerDuration) {
                        await send(.maskLocationTick)
                    }
                }
                .cancellable(id: IDs.maskLocationTimer, cancelInFlight: true)

            case .maskLocationTick:
                // `partiallyMaskedLocation` returns nil once both country and IP are fully
                // masked (or were empty/unmaskable to begin with) — that, or leaving the
                // `.protecting` state, is the timer's termination condition.
                guard case let .protecting(country, ip) = state.protectionState,
                      let masked = partiallyMaskedLocation(country: country, ip: ip)
                else {
                    return .cancel(id: IDs.maskLocationTimer)
                }
                state.$protectionState.withLock { $0 = masked }
                return .none

            case .watchConnectionStatus:
                return .publisher {
                    state
                        .$connectionState
                        .publisher
                        .removeDuplicates()
                        .receive(on: UIScheduler.shared)
                        .map(Action.newConnectionState)
                }
                .cancellable(id: IDs.watchConnectionStatus, cancelInFlight: true)

            case let .newConnectionState(connectionState):
                let location = state.userLocation?.location
                let country = countryNameProvider.countryName(forCode: location?.country ?? "") ?? ""
                let protectionState = connectionState.protectionState(country: country, ip: location?.ip ?? "")
                return .send(.newProtectionState(protectionState))

            case let .newProtectionState(protectionState):
                if case .protecting = protectionState {
                    // Deduplicate: distinct connection states can map to the same
                    // `.protecting` value, and re-subscription replays the current one.
                    // Restarting the masking animation for an identical state would flash
                    // the user's real country/IP back onto screen mid-animation.
                    guard protectionState != state.startingProtectionState else {
                        return .none
                    }
                    state.startingProtectionState = protectionState
                    state.$protectionState.withLock { $0 = protectionState }
                    return .send(.startLocationMasking)
                } else {
                    withOptionalAnimation(shouldAnimate: protectionState.shouldAnimateChange) {
                        state.$protectionState.withLock { $0 = protectionState }
                    }
                    state.startingProtectionState = nil
                    return .cancel(id: IDs.maskLocationTimer)
                }

            case let .connectionStatusBanner(.delegate(.upsellTapped(upsellMode))):
                return .send(.delegate(.upsellTapped(upsellMode)))

            case .connectionStatusBanner, .delegate:
                return .none

            case .tearDown:
                state.startingProtectionState = nil
                return .merge(
                    .cancel(id: IDs.watchConnectionStatus),
                    .cancel(id: IDs.maskLocationTimer)
                )
            }
        }
    }

    /// Advances the masking animation by one character.
    ///
    /// - Returns: the next `.protecting` state with one more character of the country or IP
    ///   masked, or `nil` when both are fully masked (or unmaskable, e.g. empty strings) and
    ///   the caller should stop the timer.
    ///
    /// While both strings still have unmasked characters, which one advances is chosen at
    /// random for a staggered visual effect; once one of them is done, the other keeps
    /// advancing on every tick, so the animation always runs to completion.
    func partiallyMaskedLocation(country: String, ip: String) -> ProtectionState? {
        let maskedCountry = country.partiallyMasked()
        let maskedIP = ip.partiallyMasked(onlyAlphanumerics: true)
        switch (maskedCountry, maskedIP) {
        case (nil, nil):
            return nil
        case let (maskedCountry?, nil):
            return .protecting(country: maskedCountry, ip: ip)
        case let (nil, maskedIP?):
            return .protecting(country: country, ip: maskedIP)
        case let (maskedCountry?, maskedIP?):
            return withRandomNumberGenerator { generator in
                Bool.random(using: &generator)
                    ? .protecting(country: maskedCountry, ip: ip)
                    : .protecting(country: country, ip: maskedIP)
            }
        }
    }
}

private extension ProtectionState {
    var shouldAnimateChange: Bool {
        switch self {
        case .protectedSecureCore, .protected:
            true
        case .resolving, .unprotected, .protecting, .killSwitchActive, .authenticationRequired:
            false
        }
    }
}
