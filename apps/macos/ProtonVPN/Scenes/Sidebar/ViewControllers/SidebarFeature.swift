//
//  Created on 24/03/2026 by Max Kupetskyi.
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
import AppKit
import Combine
import CommonNetworking
import ComposableArchitecture
import Connection
import CoreConnection
import CoreGraphics
import Domain
import Ergonomics
import ExtensionManager
import Foundation
import Modals
import NATPortMapping
import PaymentsShared
import Persistence
import ProtonCoreFeatureFlags
import Sharing
import Strings
import VPNAppCore

@Reducer
struct SidebarFeature {
    @ObservableState
    struct State: Equatable {
        @CasePathable
        enum OverlayState: Equatable {
            case hidden
            case connecting(ConnectingOverlayFeature.State)
            case autoDismiss(ConnectingOverlayFeature.State)
            case suppressed

            var connectingOverlay: ConnectingOverlayFeature.State? {
                switch self {
                case let .connecting(state), let .autoDismiss(state):
                    state
                case .hidden, .suppressed:
                    nil
                }
            }

            var isVisible: Bool {
                switch self {
                case .connecting, .autoDismiss:
                    true
                case .hidden, .suppressed:
                    false
                }
            }
        }

        @SharedReader(.connectionState) var connectionState: ConnectionState
        var connection: ConnectionFeature.State = .initialState
        var maintenance = MaintenanceFeature.State()

        enum ExpandState: Equatable {
            case compact
            case expanded
        }

        var selectedTab: SidebarTab = .countries
        var overlayState: OverlayState = .hidden
        var expandState: ExpandState = .compact
        var mapWidth: CGFloat = 600
        var isFullscreen = false
        var natPortMappingRunning = false
        var header = HeaderFeature.State()
        var countriesSection = CountriesSectionFeature.State()
        @Presents var alert: AlertState<Action.Alert>?

        @Presents var telemetryConsent: TelemetryConsentFeature.State?
        var pendingReconnectIntent: ConnectionPreparationIntent?

        var connectingOverlay: ConnectingOverlayFeature.State? {
            get { overlayState.connectingOverlay }
            set {
                guard let newValue else { return }
                switch overlayState {
                case .connecting:
                    overlayState = .connecting(newValue)
                case .autoDismiss:
                    overlayState = .autoDismiss(newValue)
                case .hidden, .suppressed:
                    break
                }
            }
        }

        var isExpandButtonHidden: Bool {
            isFullscreen
        }

        var shouldPresentLoadingOverlay: Bool {
            overlayState.isVisible
        }
    }

    enum Action {
        case connection(ConnectionFeature.Action)
        case maintenance(MaintenanceFeature.Action)

        case viewDidLoad
        case viewDidAppear
        case telemetryConsent(PresentationAction<TelemetryConsentFeature.Action>)
        case mouseDown
        case startObservingEvents
        case stopObservingEvents
        case connectedOverlayDelayElapsed
        case overlayDismissedByUser

        case windowDidResize(width: CGFloat, height: CGFloat)
        case windowDidEndLiveResize(width: CGFloat, isFullscreen: Bool)
        case windowWillEnterFullScreen
        case windowWillExitFullScreen
        case killSwitchModeChanged(KillSwitchMode)
        case planChanged(PlanChange)
        /// Refresh API announcements if polling is enabled (on start and each time the app becomes active)
        case refreshAnnouncementsIfNeeded
        case connectionStateChanged(ConnectionState)
        case syncNATPortMappingState
        case portMappingChanged(Result<PortMappingPacketResponse?, Error>)
        case syncPlutoniumState
        case connectingOverlay(ConnectingOverlayFeature.Action)

        case tabChanged(SidebarTab)
        case expandButtonTapped
        case connectionCommandReceived(ConnectionCommand)

        case header(HeaderFeature.Action)
        case countriesSection(CountriesSectionFeature.Action)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Equatable {
            /// User chose "Enable Kill Switch" on the bad-LAN alert. We flip the kill switch (which suppresses the
            /// bad-LAN intercept on the re-issued connect) and retry.
            case enableKillSwitchAndConnect(PendingConnect)
            /// User chose "Continue" on the bad-LAN alert. We retry connect bypassing intercepts.
            case connectAnywayDespiteBadLAN(PendingConnect)
            /// User chose "Connect" on the Plutonium+IKE alert. We disable Plutonium and retry.
            case disablePlutoniumAndConnect(PendingConnect)
        }
    }

    /// Captures the parameters of a `.connect` command paused while we await user input on an intercept alert
    struct PendingConnect: Equatable {
        let spec: ConnectionSpec
        let connectionProtocol: ConnectionProtocol?
        let trigger: UserInitiatedVPNChange.VPNTrigger?
        var resolvedIntercepts: Set<InterceptKind> = []
    }

    enum InterceptKind: Hashable {
        case plutoniumIKE
        case badLAN
    }

    // MARK: - Init

    init(
        environment: Environment
    ) {
        self.environment = environment
    }

    struct Environment {
        var sidebarWidth: CGFloat
        var expandButtonWidth: CGFloat
        var defaultMapWidth: CGFloat
    }

    private let environment: Environment
    @Dependency(\.sidebarEventsClient) private var sidebarEventsClient
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.pendingDisconnectCompletions) private var pendingDisconnectCompletions
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    @Dependency(\.planChangeClient) private var planChangeClient
    @Dependency(\.natPortMappingService) private var natPortMappingService
    @Dependency(\.plutoniumManager) private var plutoniumManager
    @Dependency(\.serverChangeAuthorizer) private var serverChangeAuthorizer
    @Dependency(\.networkInterfacePropertiesProvider) private var networkInterfacePropertiesProvider
    @Dependency(\.profileManager) private var profileManager
    @Dependency(\.announcementRefresher) private var announcementRefresher
    @Dependency(\.coreAlertService) private var coreAlertService
    @Dependency(\.linkOpener) private var linkOpener
    @Dependency(\.notificationManager) private var notificationManager
    @Dependency(\.date) private var date

    @Shared(.killSwitchMode) private var killSwitchMode: KillSwitchMode
    @SharedReader(.connectionProtocol) private var sharedConnectionProtocol: ConnectionProtocol
    @Shared(.plutoniumFeature) private var plutoniumFeature: PlutoniumFeatureToggle

    var body: some ReducerOf<Self> {
        Scope(state: \.connection, action: \.connection) {
            ConnectionFeature()
                ._printChanges()
        }

        Scope(state: \.header, action: \.header) {
            HeaderFeature()
        }
        Scope(state: \.countriesSection, action: \.countriesSection) {
            CountriesSectionFeature()
        }
        Scope(state: \.maintenance, action: \.maintenance) {
            MaintenanceFeature()
        }
        CombineReducers {
            lifecycleAndObservationReducer
            natPlutoniumReducer
            windowReducer
            overlayReducer
            tabReducer
            connectionCommandsReducer
            countriesSectionReducer
            connectionEventsReducer
        }
        .ifLet(\.connectingOverlay, action: \.connectingOverlay) {
            ConnectingOverlayFeature()
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$telemetryConsent, action: \.telemetryConsent) {
            TelemetryConsentFeature()
        }
    }

    private enum CancelID {
        case windowResize
        case windowEndResize
        case windowEnterFullScreen
        case windowExitFullScreen
        case overlayDelay
        case connectionCommands
        case connectionState
        case portForwardingSetting
        case portMapping
        case plutoniumSetting
        case connectionConnectCommandEffect
        case plutoniumSync
        case planChange
        case announcementRefresh
        case killSwitchSetting
    }
}

extension SidebarFeature.PendingConnect {
    /// Returns a copy with `kind` added to `resolvedIntercepts`, so the next intercept re-check (via
    /// `resolveAndPerformConnect`) skips it.
    func resolving(_ kind: SidebarFeature.InterceptKind) -> Self {
        var copy = self
        copy.resolvedIntercepts.insert(kind)
        return copy
    }
}

private extension SidebarFeature {
    var lifecycleAndObservationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .viewDidLoad:
                state.selectedTab = .countries
                @SharedReader(.mapWidth) var mapWidth
                let loadedMapWidth = mapWidth
                state.mapWidth = loadedMapWidth > Int(environment.expandButtonWidth) ? CGFloat(loadedMapWidth) : environment.defaultMapWidth
                return .merge(
                    .send(.connection(.input(.onLaunch))),
                    .send(.syncNATPortMappingState),
                    .send(.syncPlutoniumState),
                    .send(.startObservingEvents)
                )
            case .startObservingEvents:
                return .merge(
                    .send(.maintenance(.onStart)),
                    .run { send in
                        for await resize in sidebarEventsClient.windowDidResize() {
                            await send(.windowDidResize(width: resize.width, height: resize.height))
                        }
                    }
                    .cancellable(id: CancelID.windowResize),
                    .run { send in
                        for await event in sidebarEventsClient.windowDidEndLiveResize() {
                            await send(.windowDidEndLiveResize(width: event.width, isFullscreen: event.isFullscreen))
                        }
                    }
                    .cancellable(id: CancelID.windowEndResize),
                    .run { send in
                        for await _ in sidebarEventsClient.windowWillEnterFullScreen() {
                            await send(.windowWillEnterFullScreen)
                        }
                    }
                    .cancellable(id: CancelID.windowEnterFullScreen),
                    .run { send in
                        for await _ in sidebarEventsClient.windowWillExitFullScreen() {
                            await send(.windowWillExitFullScreen)
                        }
                    }
                    .cancellable(id: CancelID.windowExitFullScreen),
                    .run { send in
                        let stream = await connectionCommandClient.stream()
                        for await command in stream {
                            await send(.connectionCommandReceived(command))
                        }
                    }
                    .cancellable(id: CancelID.connectionCommands),
                    .run { send in
                        for await _ in portForwardingPropertyProvider.portForwardingStream() {
                            await send(.syncNATPortMappingState)
                        }
                    }
                    .cancellable(id: CancelID.portForwardingSetting),
                    .publisher {
                        natPortMappingService.portMappingStream
                            .removeDuplicates(by: { previous, next in
                                switch (previous, next) {
                                case let (.success(previousMapping), .success(nextMapping)):
                                    previousMapping?.mappedExternalPort == nextMapping?.mappedExternalPort
                                case (.success, .failure), (.failure, .success):
                                    false
                                case (.failure, .failure):
                                    // One failure is as good as another.
                                    true
                                }
                            })
                            .map(Action.portMappingChanged)
                    }
                    .cancellable(id: CancelID.portMapping),
                    .run { send in
                        @SharedReader(.plutoniumFeature) var plutoniumFeature
                        for await _ in $plutoniumFeature.publisher.values {
                            await send(.syncPlutoniumState)
                        }
                    }
                    .cancellable(id: CancelID.plutoniumSetting),
                    .run { send in
                        @SharedReader(.killSwitchMode) var killSwitchMode
                        for await value in $killSwitchMode.publisher.removeDuplicates().values.dropFirst() {
                            await send(.killSwitchModeChanged(value))
                        }
                    }
                    .cancellable(id: CancelID.killSwitchSetting),
                    .run { send in
                        for await planChange in planChangeClient.events() {
                            await send(.planChanged(planChange))
                        }
                    }
                    .cancellable(id: CancelID.planChange),
                    // Refresh announcements now and whenever the app returns to the foreground. Scoped to the logged-in
                    // sidebar (announcements are per-user).
                    .send(.refreshAnnouncementsIfNeeded),
                    .publisher {
                        NotificationCenter.default
                            .publisher(for: NSApplication.didBecomeActiveNotification)
                            .receive(on: DispatchQueue.main)
                            .map { _ in Action.refreshAnnouncementsIfNeeded }
                    }
                    .cancellable(id: CancelID.announcementRefresh),
                    .publisher {
                        @SharedReader(.connectionState) var connectionState
                        return $connectionState.publisher
                            .removeDuplicates()
                            .map { state in Action.connectionStateChanged(state) }
                    }
                    .cancellable(id: CancelID.connectionState)
                )
            case .stopObservingEvents:
                return .merge(
                    .send(.maintenance(.onStop)),
                    .cancel(id: CancelID.windowResize),
                    .cancel(id: CancelID.windowEndResize),
                    .cancel(id: CancelID.windowEnterFullScreen),
                    .cancel(id: CancelID.windowExitFullScreen),
                    .cancel(id: CancelID.overlayDelay),
                    .cancel(id: CancelID.connectionCommands),
                    .cancel(id: CancelID.connectionState),
                    .cancel(id: CancelID.portForwardingSetting),
                    .cancel(id: CancelID.plutoniumSetting),
                    .cancel(id: CancelID.connectionConnectCommandEffect),
                    .cancel(id: CancelID.plutoniumSync),
                    .cancel(id: CancelID.planChange),
                    .cancel(id: CancelID.announcementRefresh),
                    .cancel(id: CancelID.killSwitchSetting)
                )
            case let .planChanged(planChange):
                // update the persisted feature settings so a downgrade clears paid features
                // and an upgrade re-enables NetShield
                return .run { _ in applyPlanChangeFeatureResets(planChange) }
            case .refreshAnnouncementsIfNeeded:
                return .run { _ in
                    @SharedReader(.featureFlags) var featureFlags
                    guard featureFlags.pollNotificationAPI else { return }
                    announcementRefresher.tryRefreshing()
                }
            case .viewDidAppear:
                if TelemetryOptIn.needsReconsent, state.telemetryConsent == nil {
                    state.telemetryConsent = TelemetryConsentFeature.State()
                }
                return .none
            case .mouseDown:
                return .none
            default:
                return .none
            }
        }
    }

    var windowReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .windowDidResize(width, _):
                state.expandState = width <= environment.sidebarWidth + environment.expandButtonWidth ? .compact : .expanded
                return .none
            case let .windowDidEndLiveResize(width, isFullscreen):
                state.expandState = width <= environment.sidebarWidth + environment.expandButtonWidth ? .compact : .expanded
                guard !isFullscreen, state.expandState == .expanded, width > environment.sidebarWidth + environment.expandButtonWidth else {
                    return .none
                }
                let mapWidth = Int(width - environment.sidebarWidth)
                state.mapWidth = CGFloat(mapWidth)
                @Shared(.mapWidth) var storedMapWidth
                $storedMapWidth.withLock { $0 = mapWidth }
                return .none
            case .windowWillEnterFullScreen:
                state.isFullscreen = true
                return .none
            case .windowWillExitFullScreen:
                state.isFullscreen = false
                return .none
            default:
                return .none
            }
        }
    }

    var overlayReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .killSwitchModeChanged(mode):
                // If we're in zero-peer mode and the new mode no longer wants persistent blocking (Off or Standard),
                // tear the tunnel down so the user regains connectivity. Otherwise the user is stuck with no internet.
                if !mode.isAdvanced, state.connectionState.is(\.killSwitchActive) {
                    return .send(.connection(.input(.disconnect)))
                }
                // Otherwise: leave the live tunnel untouched. The mode is already persisted (@Shared, written by the
                // settings picker) and takes effect on the next connection.
                return .none
            case let .connectionStateChanged(connectionState):
                switch connectionState {
                case .resolving:
                    // `.resolving` is a transient app-startup state. It is not user-initiated, so we don't show the
                    // connecting overlay. Otherwise the user sees a brief connecting flash at every launch before the
                    // resolved (typically `.disconnected`) state arrives. `.connecting` (a real user-initiated attempt)
                    // still shows the overlay.
                    return .none
                case .connecting:
                    if state.overlayState != .suppressed {
                        beginConnectingOverlay(&state)
                        syncConnectingOverlayState(&state, connectionState: connectionState)
                    }
                    return .cancel(id: CancelID.overlayDelay)
                case .authenticationRequired:
                    state.overlayState = .hidden
                    return .cancel(id: CancelID.overlayDelay)
                case .connected:
                    // .connected signals the in-place settings update has finished; clear the suppression so subsequent
                    // passive reconnects are visible.
                    if state.overlayState == .suppressed {
                        state.overlayState = .hidden
                        return .cancel(id: CancelID.overlayDelay)
                    }
                    // Only run the auto-dismiss transition when the connect was app-initiated (i.e. we were previously
                    // showing the connecting overlay). For OS-initiated tunnels (started from System Settings,
                    // on-demand, etc.) there is no overlay to gracefully tear down, so skip the brief "connected"
                    // flash.
                    guard state.overlayState.is(\.connecting) else {
                        state.overlayState = .hidden
                        return .cancel(id: CancelID.overlayDelay)
                    }
                    transitionToAutoDismiss(&state, connectionState: connectionState)
                    return .run { send in
                        try await clock.sleep(for: .seconds(3))
                        await send(.connectedOverlayDelayElapsed)
                    }
                    .cancellable(id: CancelID.overlayDelay, cancelInFlight: true)
                case .disconnecting, .disconnected, .killSwitchActive:
                    state.overlayState = .hidden
                    return .cancel(id: CancelID.overlayDelay)
                }
            case .connectedOverlayDelayElapsed:
                state.overlayState = .hidden
                return .none
            case .overlayDismissedByUser:
                state.overlayState = .hidden
                return .cancel(id: CancelID.overlayDelay)
            case .connectingOverlay(.delegate(.dismissRequested)):
                return .send(.overlayDismissedByUser)
            default:
                return .none
            }
        }
    }

    var tabReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabChanged(tab):
                state.selectedTab = tab
                return .none
            case .expandButtonTapped:
                state.expandState = state.expandState == .compact ? .expanded : .compact
                return .none
            default:
                return .none
            }
        }
    }

    var connectionCommandsReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .connectionCommandReceived(.connect(spec, connectionProtocol, trigger)):
                if trigger == .changeServer {
                    let availability = serverChangeAuthorizer.serverChangeAvailability()
                    if case let .unavailable(until, duration, exhaustedSkips) = availability {
                        let intent = connectionPreparationIntent(
                            spec: spec,
                            connectionProtocol: connectionProtocol ?? sharedConnectionProtocol
                        )
                        state.pendingReconnectIntent = intent
                        return .send(.countriesSection(.quickSettings(.presentUpsell(
                            .cantSkip(
                                before: until,
                                totalDuration: duration,
                                longSkip: exhaustedSkips
                            )
                        ))))
                    }
                }
                let pending = PendingConnect(spec: spec, connectionProtocol: connectionProtocol, trigger: trigger)
                return resolveAndPerformConnect(&state, pending: pending)
            case let .connectionCommandReceived(.disconnect(trigger, completion)):
                state.overlayState = .hidden
                let alreadyDisconnected = state.connectionState.is(\.disconnected)
                return .merge(
                    .cancel(id: CancelID.connectionConnectCommandEffect),
                    .cancel(id: CancelID.overlayDelay),
                    .run { send in
                        if let completion {
                            if alreadyDisconnected {
                                await MainActor.run { completion() }
                            } else {
                                await pendingDisconnectCompletions.enqueue(completion)
                            }
                        }
                        AppEvent.userInitiatedVPNChange.post(trigger)
                        await send(.connection(.input(.disconnect)))
                    }
                )
            case .connectionCommandReceived(.retry):
                let spec = state.connectionState.resolvedSpec ?? ConnectionSpec()
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: sharedConnectionProtocol
                )
                log.info(
                    "Reconnecting via retry command",
                    category: .connectionConnect,
                    metadata: ["spec.location": "\(spec.location)"]
                )
                beginConnectingOverlay(&state)
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .run { send in
                        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                        await send(.connection(.input(.connect(intent))))
                    }
                    .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)
                )
            case let .connectionCommandReceived(.reconnect(connectionProtocol)):
                let spec = state.connectionState.resolvedSpec ?? ConnectionSpec()
                let intent = connectionPreparationIntent(
                    spec: spec,
                    connectionProtocol: connectionProtocol ?? sharedConnectionProtocol
                )
                log.info(
                    "Reconnecting via reconnect command",
                    category: .connectionConnect,
                    metadata: ["spec.location": "\(spec.location)"]
                )
                beginConnectingOverlay(&state)
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .run { send in
                        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(.auto))
                        await send(.connection(.input(.connect(intent))))
                    }
                    .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)
                )
            case let .connectionCommandReceived(.applySettings(settings)):
                state.overlayState = .suppressed
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .send(.connection(.input(.applySettings(settings))))
                )
            case let .connectionCommandReceived(.clearConnectionData(completion)):
                return .run { send in
                    await send(.connection(.input(.onLogout)))
                    await completion?()
                }
            case let .alert(.presented(.enableKillSwitchAndConnect(pending))):
                // The bad-LAN intercept offers to enable Kill Switch to block leaks; Standard is the minimal protection
                // that satisfies this
                $killSwitchMode.withLock { $0 = .standard }
                return resolveAndPerformConnect(&state, pending: pending.resolving(.badLAN))
            case let .alert(.presented(.connectAnywayDespiteBadLAN(pending))):
                return resolveAndPerformConnect(&state, pending: pending.resolving(.badLAN))
            case let .alert(.presented(.disablePlutoniumAndConnect(pending))):
                $plutoniumFeature.withLock { $0.disable() }
                return resolveAndPerformConnect(&state, pending: pending.resolving(.plutoniumIKE))
            default:
                return .none
            }
        }
    }

    private var portForwardingNotificationsEnabled: Bool {
        AuthorizedFeatureValue<PortForwardingNotifications>().value() == .on
    }

    var countriesSectionReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .countriesSection(.delegate(.openProfilesTab)):
                state.selectedTab = .profiles
                return .none
            case .countriesSection(.quickSettings(.destination(.presented(.upsell(.skipActionTapped))))):
                guard let intent = state.pendingReconnectIntent else {
                    return .none
                }
                state.pendingReconnectIntent = nil
                beginConnectingOverlay(&state)
                return .merge(
                    .cancel(id: CancelID.overlayDelay),
                    .send(.connection(.input(.connect(intent))))
                )
            case .countriesSection(.quickSettings(.destination(.presented(.upsell(.upgradeTapped))))),
                 .countriesSection(.quickSettings(.destination(.dismiss))):
                state.pendingReconnectIntent = nil
                return .none
            default:
                return .none
            }
        }
    }

    var connectionEventsReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .connection(.delegate(.connectionFailed(error))):
                SentryHelper.shared?.log(error: error)
                // Pre-connection failures (network unreachable, etc.) emit only the delegate and never transition
                // `connectionState` to `.disconnected`, so the overlay reducer's normal dismissal path doesn't fire.
                // Hide it explicitly when the connection layer is back at rest.
                if state.connectionState.is(\.disconnected) {
                    state.overlayState = .hidden
                }
                state.alert = connectionFailureAlert(for: error)
                return .cancel(id: CancelID.overlayDelay)
            case let .connection(.delegate(.stateChanged(connectionState))):
                log.debug("Connection layer state update \(connectionState)")
                return .merge(
                    .send(.syncNATPortMappingState),
                    .send(.syncPlutoniumState),
                    .run { _ in
                        if connectionState.is(\.disconnected) {
                            await pendingDisconnectCompletions.drainAndInvoke()
                        }
                    }
                )
            case let .connection(.delegate(.intentResolutionFailed(intent, resolutionError))):
                log.warning(
                    "Intent resolution failed; presenting upsell",
                    category: .connection,
                    metadata: [
                        "intent.spec.location": "\(intent.spec.location)",
                        "intent.spec.features": "\(intent.spec.features)",
                        "intent.connectionProtocol": "\(intent.connectionProtocol)",
                        "resolutionError": "\(resolutionError)",
                        "overlayState": "\(state.overlayState)",
                        "connectionState": "\(state.connectionState)",
                    ]
                )
                SentryHelper.shared?.log(error: resolutionError)
                // Intent-resolution failures (e.g. unavailable country, secure core) reject the connect attempt
                // *before* the connection state transitions to `.connecting`, so the overlay reducer never sees a
                // `.disconnected` change to dismiss on. Hide the overlay here so the user only sees the upsell, not a
                // stuck "Connecting..." overlay behind it.
                state.overlayState = .hidden
                let cancelOverlayDelay: Effect<Action> = .cancel(id: CancelID.overlayDelay)
                switch resolutionError {
                case .secureCoreUnavailable:
                    state.pendingReconnectIntent = nil
                    return .merge(
                        cancelOverlayDelay,
                        .send(.countriesSection(.quickSettings(.presentUpsell(.secureCore))))
                    )
                case let .specificCountryUnavailable(countryCode):
                    state.pendingReconnectIntent = nil
                    return .merge(
                        cancelOverlayDelay,
                        .send(.countriesSection(.quickSettings(.presentUpsell(
                            .country(countryCode: countryCode)
                        ))))
                    )
                case .serverChangeUnavailable:
                    let availability = serverChangeAuthorizer.serverChangeAvailability()
                    guard case let .unavailable(until, duration, exhaustedSkips) = availability else {
                        state.pendingReconnectIntent = nil
                        return cancelOverlayDelay
                    }
                    state.pendingReconnectIntent = intent
                    return .merge(
                        cancelOverlayDelay,
                        .send(.countriesSection(.quickSettings(.presentUpsell(
                            .cantSkip(
                                before: until,
                                totalDuration: duration,
                                longSkip: exhaustedSkips
                            )
                        ))))
                    )
                }
            case let .connection(.delegate(.localAgentNotice(error))) where error.twoFactorRequired:
                state.overlayState = .hidden
                let connectionCommandClient = connectionCommandClient
                let linkOpener = linkOpener
                coreAlertService.push(
                    alert: TwoFactorRequiredAlert(
                        onConfirm: { linkOpener.open(CommonNetworking.ObfuscatedConstants.fidoPortal) },
                        onCancel: { connectionCommandClient.send(.disconnect(.fidoAuthentication)) }
                    )
                )
                return .cancel(id: CancelID.overlayDelay)
            case .connection:
                return .none
            default:
                return .none
            }
        }
    }

    var natPlutoniumReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .syncNATPortMappingState:
                let shouldRunNatPortMapping = VPNFeatureFlagType.portForwarding.enabled
                    && portForwardingPropertyProvider.getPortForwarding() == true
                    && connectionStateSupportsNatPortMapping(state.connectionState)
                guard shouldRunNatPortMapping != state.natPortMappingRunning else {
                    return .none
                }
                state.natPortMappingRunning = shouldRunNatPortMapping
                if shouldRunNatPortMapping {
                    guard let gatewayAddress = natPortMappingGatewayAddress(from: state.connectionState) else {
                        state.natPortMappingRunning = false
                        log.error("Cannot start NAT port mapping - unable to determine gateway address", category: .connection)
                        return .none
                    }
                    return .run { _ in
                        natPortMappingService.startPortMapping(gatewayAddress: gatewayAddress)
                        log.info("NAT port mapping service started", category: .connection)
                    }
                } else {
                    state.header.mappedPort = nil
                    return .run { _ in
                        await natPortMappingService.cancelPortMapping()
                        log.info("NAT port mapping service stopped", category: .connection)
                    }
                }

            case let .portMappingChanged(result):
                switch result {
                case let .success(mapping):
                    // A mapping the server has already let expire is no longer a port we have.
                    guard let mapping, mapping.deadlineDate > date.now else {
                        state.header.mappedPort = nil
                        return .none
                    }
                    state.header.mappedPort = mapping.mappedExternalPort
                    log.info(
                        "Port forwarding mapped a port",
                        category: .connection,
                        metadata: ["port": "\(mapping.mappedExternalPort)", "notify": "\(portForwardingNotificationsEnabled)"]
                    )
                    guard portForwardingNotificationsEnabled else { return .none }
                    let portNumber = mapping.mappedExternalPort
                    return .run { _ in
                        await MainActor.run { notificationManager.displayPFChange(portNumber: portNumber) }
                    }

                case .failure:
                    state.header.mappedPort = nil
                    log.error(
                        "Port forwarding could not get a port",
                        category: .connection,
                        metadata: ["notify": "\(portForwardingNotificationsEnabled)"]
                    )
                    guard portForwardingNotificationsEnabled else { return .none }
                    return .run { _ in
                        await MainActor.run { notificationManager.displayPFError() }
                    }
                }

            case .syncPlutoniumState:
                let connectionState = state.connectionState
                let feature = plutoniumFeature
                return .run { _ in
                    guard FeatureFlagsRepository.shared
                        .isEnabled(VPNFeatureFlagType.plutoniumMacOS, reloadValue: true), case .enabled = feature
                    else {
                        try await plutoniumManager.stop()
                        return
                    }
                    if connectionState.is(\.connected) {
                        try await plutoniumManager.start()
                    } else {
                        try await plutoniumManager.stop()
                    }
                } catch: { error, _ in
                    if case let PlutoniumManagerError.saveFailed(saveError) = error {
                        log.error("Error while saving plutonium manager: \(saveError)")
                    } else {
                        log.error("Error while updating plutonium state: \(error.localizedDescription)")
                    }
                    SentryHelper.shared?.log(error: error)
                }
                .cancellable(id: CancelID.plutoniumSync, cancelInFlight: true)

            default:
                return .none
            }
        }
    }

    /// Single entry point for "user wants to connect with these parameters". Re-evaluates `interceptAlert` against the
    /// current state every time it's called so that resolving one intercept (e.g. disabling Plutonium) doesn't silently
    /// skip a later one (e.g. bad LAN). Already-resolved intercepts are skipped via `pending.resolvedIntercepts`.
    func resolveAndPerformConnect(_ state: inout State, pending: PendingConnect) -> Effect<Action> {
        if let alert = interceptAlert(for: pending) {
            state.alert = alert
            return .none
        }
        return performConnect(&state, pending: pending)
    }

    /// Encapsulates the side effects of dispatching a `.connect` command after intercept checks have been resolved
    /// (either none fired or the user confirmed via alert).
    func performConnect(_ state: inout State, pending: PendingConnect) -> Effect<Action> {
        let intent = connectionPreparationIntent(
            spec: pending.spec,
            connectionProtocol: pending.connectionProtocol ?? sharedConnectionProtocol
        )
        beginConnectingOverlay(&state)
        return .merge(
            .cancel(id: CancelID.overlayDelay),
            .run { [trigger = pending.trigger] send in
                AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect(trigger))
                await send(.connection(.input(.connect(intent))))
            }
            .cancellable(id: CancelID.connectionConnectCommandEffect, cancelInFlight: true)
        )
    }

    /// Returns an alert if any pre-connect intercept (e.g. misconfigured LAN, Plutonium+IKE) applies to the pending
    /// connect; otherwise `nil`. Intercepts are evaluated in priority order. Once one fires, later policies do not run
    /// for this call. Intercepts the user has already resolved (tracked in `pending.resolvedIntercepts`) are skipped so
    /// a follow-up "Continue anyway" / "Connect" doesn't loop on its own alert and so later intercepts further down the
    /// chain still get a chance to fire.
    func interceptAlert(for pending: PendingConnect) -> AlertState<Action.Alert>? {
        let effectiveProtocol = pending.connectionProtocol ?? sharedConnectionProtocol

        // Plutonium + IKE conflict (macOS only). Fires when the user has Split Tunneling enabled and tries to connect
        // with IKEv2, which the Plutonium extension does not support. Confirming the alert disables Plutonium for this
        // connection.
        if !pending.resolvedIntercepts.contains(.plutoniumIKE),
           case .enabled = plutoniumFeature,
           effectiveProtocol == .vpnProtocol(.ike) {
            // Title includes the profile name when the connect originates from a saved profile.
            let title: String = if let profileID = pending.spec.profileId,
                                   let profileName = profileManager.profile(id: profileID)?.name {
                Localizable.splitTunnelingConnectToProfileNameAlertTitle(profileName)
            } else {
                Localizable.splitTunnelingConnectToProfileAlertTitle
            }
            return AlertState {
                TextState(title)
            } actions: {
                ButtonState(action: .disablePlutoniumAndConnect(pending)) {
                    TextState(Localizable.connect)
                }
                ButtonState(role: .cancel) {
                    TextState(Localizable.cancel)
                }
            } message: {
                TextState(Localizable.splitTunnelingConnectToProfileAlertDescription)
            }
        }

        // Misconfigured LAN. Fires when an interface uses a non-RFC1918 subnet that the OS would otherwise route around
        // the tunnel. Kill Switch fully mitigates the issue.
        @SharedReader(.featureFlags) var featureFlags
        if !pending.resolvedIntercepts.contains(.badLAN),
           featureFlags.unsafeLanWarnings,
           !killSwitchMode.isProtected,
           let bad = networkInterfacePropertiesProvider.firstBadInterface() {
            return bad.interceptAlert(
                enableKillSwitch: .enableKillSwitchAndConnect(pending),
                connectAnyway: .connectAnywayDespiteBadLAN(pending)
            )
        }

        return nil
    }

    func beginConnectingOverlay(_ state: inout State) {
        var overlay = state.connectingOverlay ?? ConnectingOverlayFeature.State()
        overlay.beginConnecting(
            selectedProtocol: sharedConnectionProtocol,
            killSwitchEnabled: killSwitchMode.isProtected
        )
        state.overlayState = .connecting(overlay)
    }

    func transitionToAutoDismiss(_ state: inout State, connectionState: ConnectionState) {
        var overlay = state.connectingOverlay ?? ConnectingOverlayFeature.State()
        overlay.sync(
            connectionState: connectionState,
            selectedProtocol: sharedConnectionProtocol,
            killSwitchEnabled: killSwitchMode.isProtected
        )
        state.overlayState = .autoDismiss(overlay)
    }

    func syncConnectingOverlayState(_ state: inout State, connectionState: ConnectionState) {
        guard var overlay = state.connectingOverlay else {
            return
        }
        overlay.sync(
            connectionState: connectionState,
            selectedProtocol: sharedConnectionProtocol,
            killSwitchEnabled: killSwitchMode.isProtected
        )
        state.connectingOverlay = overlay
    }

    func connectionFailureAlert(for error: ConnectionError) -> AlertState<Action.Alert> {
        let alert = error.alert
        return AlertState {
            TextState(String(localized: alert.title))
        } message: {
            TextState(String(localized: alert.message))
        }
    }

    func connectionPreparationIntent(
        spec: ConnectionSpec,
        connectionProtocol: ConnectionProtocol
    ) -> ConnectionPreparationIntent {
        let spec = enforceP2PIfPortForwardingEnabled(spec)
        @SharedReader(.smartProtocolConfig) var smartProtocolConfig
        let acceptableProtocols: ProtocolSupport = switch connectionProtocol {
        case let .vpnProtocol(vpnProtocol):
            vpnProtocol.protocolSupport
        case .smartProtocol:
            smartProtocolConfig.supportedProtocols
                .reduce(.zero) { $0.union($1.protocolSupport) }
        }
        return ConnectionPreparationIntent(
            spec: spec,
            connectionProtocol: connectionProtocol,
            acceptableProtocols: acceptableProtocols
        )
    }

    func enforceP2PIfPortForwardingEnabled(_ spec: ConnectionSpec) -> ConnectionSpec {
        guard portForwardingPropertyProvider.getPortForwarding() == true else {
            return spec
        }
        switch spec.location {
        case .any, .country, .city, .state:
            if spec.features.contains(.p2p) {
                return spec
            }
            var features = spec.features
            features.insert(.p2p)
            return ConnectionSpec(location: spec.location, features: features, profileId: spec.profileId)
        case .exact, .secureCore, .gateway:
            return spec
        }
    }

    func connectionStateSupportsNatPortMapping(_ connectionState: ConnectionState) -> Bool {
        connectionState.is(\.connected)
    }

    /// The address NAT-PMP requests go to, or `nil` when the protocol in use is still unknown.
    func natPortMappingGatewayAddress(from connectionState: ConnectionState) -> String? {
        let activeVpnProtocol = connectionState.resolvedVpnProtocol ?? currentlySelectedVpnProtocol()
        return activeVpnProtocol?.gatewayAddress
    }

    func currentlySelectedVpnProtocol() -> VpnProtocol? {
        switch sharedConnectionProtocol {
        case let .vpnProtocol(vpnProtocol):
            vpnProtocol
        case .smartProtocol:
            nil
        }
    }
}
