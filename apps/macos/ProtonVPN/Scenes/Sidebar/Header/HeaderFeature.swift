//
//  Created on 11/08/2026 by Max Kupetskyi.
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

import Announcement
import ComposableArchitecture
import Connection
import Dependencies
import Domain
import Foundation
import Sharing
import VPNAppCore
import VPNShared

@Reducer
struct HeaderFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.connectionState) var connectionState: ConnectionState
        @SharedReader(.userLocation) var userLocation: StoredUserLocation?
        @SharedReader(.userTier) var userTier: VpnTier?

        /// Transfer rate from the most recent sample. `nil` before the first one and while disconnected
        var bitrate: Bitrate?

        var serverChangeAvailability: ServerChangeAuthorizer.ServerChangeAvailability = .available

        /// The announcements bell, `nil` when there is no offer to show.
        var bell: Bell?

        /// The forwarded port to show, set by the sidebar, which owns port forwarding.
        var mappedPort: UInt16?

        init() {}
    }

    struct Bell: Equatable {
        var iconURL: URL?
        var tooltip: String?
        var hasUnread: Bool
    }

    enum Action {
        case onAppear
        case onDisappear

        case quickConnectTapped
        case changeServerTapped
        case announcementsBellTapped

        case connectionStateChanged(ConnectionState)
        case bitrateSampled(Bitrate)
        case announcementsChanged
        case serverChangeCooldownElapsed
    }

    /// How often the transfer rate is sampled, in seconds.
    private static let bitrateInterval: TimeInterval = 1

    private enum CancelID {
        case bitrate
        case announcements
        case connectionState
        case serverChangeCooldown
    }

    @Dependency(\.announcementManager) private var announcementManager
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.coreAlertService) private var coreAlertService
    @Dependency(\.date) private var date
    @Dependency(\.imagePrefetcher) private var imagePrefetcher
    @Dependency(\.networkTraffic) private var networkTraffic
    @Dependency(\.serverChangeAuthorizer) private var serverChangeAuthorizer

    @SharedReader(.killSwitchMode) private var killSwitchMode: KillSwitchMode

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let cooldown = refreshServerChangeAvailability(&state)
                let sampling = startSamplingBitrate(&state)
                return .merge(
                    cooldown,
                    sampling,
                    .publisher { [publisher = state.$connectionState.publisher] in
                        publisher
                            .removeDuplicates()
                            .map(Action.connectionStateChanged)
                    }
                    .cancellable(id: CancelID.connectionState, cancelInFlight: true),
                    .publisher {
                        announcementManager.announcementsPublisher()
                            .map { _ in Action.announcementsChanged }
                    }
                    .cancellable(id: CancelID.announcements, cancelInFlight: true)
                )

            case .onDisappear:
                state.bitrate = nil
                return .merge(
                    .cancel(id: CancelID.bitrate),
                    .cancel(id: CancelID.announcements),
                    .cancel(id: CancelID.connectionState),
                    .cancel(id: CancelID.serverChangeCooldown)
                )

            case let .connectionStateChanged(newState):
                let cooldown = refreshServerChangeAvailability(&state)
                let sampling = startSamplingBitrate(&state, connectionState: newState)
                return .merge(cooldown, sampling)

            case let .bitrateSampled(bitrate):
                state.bitrate = bitrate
                return .none

            case .serverChangeCooldownElapsed:
                return refreshServerChangeAvailability(&state)

            case .quickConnectTapped:
                guard state.isConnected || state.isAuthenticationRequired else {
                    log.debug("Connect requested by selecting Quick connect", category: .connectionConnect, event: .trigger)
                    connectionCommandClient.quickConnect(trigger: .quick)
                    return .none
                }
                guard advancedKillSwitchActive(state) else {
                    log.debug("Disconnect requested by selecting Quick connect", category: .connectionDisconnect, event: .trigger)
                    connectionCommandClient.send(.disconnect(.quick))
                    return .none
                }
                coreAlertService.push(alert: DisconnectWithAdvancedKillSwitchAlert(confirmHandler: { [connectionCommandClient] in
                    log.debug("Disconnect confirmed with Advanced kill switch active", category: .connectionDisconnect, event: .trigger)
                    connectionCommandClient.send(.disconnect(.quick))
                }))
                return .none

            case .changeServerTapped:
                @SharedReader(.connectionProtocol) var connectionProtocol
                connectionCommandClient.send(
                    .connect(ConnectionSpec(location: .any(.random), features: []), connectionProtocol, .changeServer)
                )
                return .none

            case .announcementsBellTapped:
                return .run { _ in
                    await MainActor.run {
                        AnnouncementOfferCoordinator().presentCurrentAnnouncement()
                    }
                }

            case .announcementsChanged:
                state.bell = makeBell()
                let urls = announcementManager.offerImagePrefetchURLs()
                guard !urls.isEmpty else { return .none }
                return .run { _ in await imagePrefetcher.prefetchURLs(urls) }
            }
        }
    }

    // MARK: - Effects

    /// Samples the transfer rate every second while connected, and stops otherwise.
    private func startSamplingBitrate(_ state: inout State, connectionState: ConnectionState? = nil) -> Effect<Action> {
        guard (connectionState ?? state.connectionState).isConnected else {
            state.bitrate = nil
            return .cancel(id: CancelID.bitrate)
        }
        return .run { send in
            var previous = networkTraffic.counters()
            for await _ in clock.timer(interval: .seconds(Self.bitrateInterval)) {
                let current = networkTraffic.counters()
                await send(.bitrateSampled(
                    Bitrate(previous: previous, current: current, interval: Self.bitrateInterval)
                ))
                previous = current
            }
        }
        .cancellable(id: CancelID.bitrate, cancelInFlight: true)
    }

    /// Reads the authorizer, then waits for the cooldown to run out so the button can enable itself.
    private func refreshServerChangeAvailability(_ state: inout State) -> Effect<Action> {
        state.serverChangeAvailability = serverChangeAuthorizer.serverChangeAvailability()

        guard case let .unavailable(until, _, _) = state.serverChangeAvailability, until > date.now else {
            return .cancel(id: CancelID.serverChangeCooldown)
        }
        let remaining = until.timeIntervalSince(date.now)
        return .run { send in
            try await clock.sleep(for: .seconds(remaining))
            await send(.serverChangeCooldownElapsed)
        }
        .cancellable(id: CancelID.serverChangeCooldown, cancelInFlight: true)
    }

    // MARK: - Reading dependencies

    private func makeBell() -> Bell? {
        @SharedReader(.featureFlags) var featureFlags
        guard featureFlags.pollNotificationAPI, announcementManager.shouldShowAnnouncementsIcon() else {
            return nil
        }
        let offer = announcementManager.currentOfferAnnouncement?.offer
        return Bell(
            iconURL: announcementManager.announcementIconURL,
            tooltip: offer?.panel?.title ?? offer?.label,
            hasUnread: announcementManager.hasUnreadAnnouncements()
        )
    }

    private func advancedKillSwitchActive(_ state: State) -> Bool {
        killSwitchMode.isAdvanced && state.connectionState.tunnelKillSwitch
    }
}

// MARK: - What the view renders

extension HeaderFeature.State {
    enum Title: Equatable {
        case authenticationRequired
        case killSwitchActive
        case unprotected
        case unavailable
        case secureCore(entryCountryCode: String, exitCountryCode: String)
        case server(countryCode: String, name: String)
    }

    enum AddressLine: Equatable {
        case authenticationRequired
        case killSwitchActive
        case address(String?)
    }

    enum ConnectButtonKind: Equatable {
        case quickConnect
        case disconnect
    }

    var isConnected: Bool {
        connectionState.isConnected
    }

    var isAuthenticationRequired: Bool {
        connectionState.is(\.authenticationRequired)
    }

    var title: Title {
        if isAuthenticationRequired {
            return .authenticationRequired
        }
        if connectionState.is(\.killSwitchActive) {
            return .killSwitchActive
        }
        if !connectionState.tunnelActive {
            return .unprotected
        }
        guard let server = connectionState.resolvedServer else {
            return .unavailable
        }
        if case let .secureCore(entryCountryCode) = server.logical.kind {
            return .secureCore(
                entryCountryCode: entryCountryCode,
                exitCountryCode: server.logical.exitCountryCode
            )
        }
        return .server(countryCode: server.logical.exitCountryCode, name: server.logical.name)
    }

    var addressLine: AddressLine {
        if isAuthenticationRequired {
            return .authenticationRequired
        }
        if connectionState.is(\.killSwitchActive) {
            return .killSwitchActive
        }
        return .address(connectionState.vpnExitIP ?? userLocation?.location.ip)
    }

    var connectedCountryCode: String? {
        guard isConnected else { return nil }
        return connectionState.resolvedServer?.logical.exitCountryCode
    }

    var serverLoad: Int? {
        guard isConnected else { return nil }
        return connectionState.resolvedServer?.logical.load
    }

    var vpnProtocolName: String? {
        guard isConnected else { return nil }
        return connectionState.resolvedVpnProtocol?.localizedDescription
    }

    var connectButtonKind: ConnectButtonKind {
        isConnected || isAuthenticationRequired ? .disconnect : .quickConnect
    }

    var showsKillSwitchIcon: Bool {
        connectionState.is(\.killSwitchActive)
    }

    var showsChangeServer: Bool {
        isConnected && userTier?.isFree == true
    }

    /// When the user may change server again, or `nil` if they may now.
    var changeServerAllowedDate: Date? {
        guard case let .unavailable(until, _, _) = serverChangeAvailability else { return nil }
        return until
    }
}
