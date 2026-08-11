//
//  Created on 17.05.23.
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
import Connection
import ConnectionDetails
import ConnectionDetailsShared
import ConnectionInventory
import CoreConnection // LocalAgent
import Dependencies
import Domain
import ExtensionSync
import Foundation
import ModalsServices
import NetShield
import Payments
import PaymentsShared
import PCAP
import PCAPShared
import ProtonCoreFeatureFlags
import Sharing
import Strings
import VPNAppCore

@Reducer
public struct HomeFeature {
    @Dependency(\.serverChangeAuthorizer) private var authorizer
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.planChangeClient) private var planChangeClient
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.announcementRefresher) private var announcementRefresher
    #if os(iOS)
        @Dependency(\.openCredentiallessSignUp) private var openCredentiallessSignUp
    #endif

    @SharedReader(.userTier) private var userTier: VpnTier?

    @Reducer
    public enum Destination {
        case changeServer(ChangeServerFeature)
        case connectionDetails(ConnectionScreenFeature)
        case freeConnectionsInfo(FreeConnectionInfoFeature)
        case defaultConnection(DefaultConnectionFeature)
        case whatsNew(WhatsNewPresenterFeature)
        case payments(PaymentsMainFeature)
        case sessionCaptured(SessionCapturedFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var recents: RecentsFeature.State
        public var connectionCard: HomeConnectionCardFeature.State
        package var sharedProperties: SharedPropertiesFeature.State
        package var announcementBanner: AnnouncementBannerFeature.State
        package var whatsNewChecker: WhatsNewCheckerFeature.State
        package var maintenance: MaintenanceFeature.State

        fileprivate var shouldPushAlert: Bool = false

        @SharedReader(.captureSession) public var captureSession: CaptureSession = .noSession
        @SharedReader(.connectionState) public var connectionState: ConnectionState

        @Presents public var destination: Destination.State?

        public init() {
            self.connectionCard = .init()
            self.sharedProperties = .init()
            self.recents = .init()
            self.announcementBanner = .noBanner
            self.whatsNewChecker = .init()
            self.maintenance = .init()
        }
    }

    private enum CancelID {
        case connectionState
        case planChange
        case captureSession
        case announcementRefresh
    }

    public enum Action {
        /// This must be called once
        case onStart

        case onAppear
        case onDisappear

        case changeServer
        case didDismissChangeServer

        case planChanged(PlanChange)
        /// Refresh API announcements if polling is enabled (on start and each time the app becomes active)
        case refreshAnnouncementsIfNeeded

        case newCaptureSession(CaptureSession)
        case recents(RecentsFeature.Action)
        case connectionCard(HomeConnectionCardFeature.Action)
        case connectionFailed(ConnectionError)
        case sharedProperties(SharedPropertiesFeature.Action)
        case connectionDetails(ConnectionScreenFeature.Action)
        case freeConnectionsInfo(FreeConnectionInfoFeature.Action)
        case announcementBanner(AnnouncementBannerFeature.Action)

        case whatsNewChecker(WhatsNewCheckerFeature.Action)
        case whatsNewPresenter(WhatsNewPresenterFeature.Action)

        case maintenance(MaintenanceFeature.Action)

        /// Start bug report flow
        case helpButtonPressed

        case destination(PresentationAction<Destination.Action>)
    }

    private static let whatsNewPresentationDelay: Duration = .seconds(3)

    public init() {}

    private func upsellModalType(from bannerType: BannerType) -> UpsellModalType {
        switch bannerType {
        case .worldwideCover:
            .allCountries
        case .fasterBrowsing:
            .vpnAccelerator
        case .streaming:
            .streaming
        case .netshield:
            .netShield
        case .secureCore:
            .secureCore
        case .p2p:
            .p2pSupport
        case .devices:
            .devices
        case .tor:
            .torOverVPN
        case .more:
            .customization
        }
    }

    public var body: some Reducer<State, Action> {
        Scope(state: \.sharedProperties, action: \.sharedProperties) {
            SharedPropertiesFeature()
        }
        Scope(state: \.connectionCard, action: \.connectionCard) {
            HomeConnectionCardFeature()
        }
        Scope(state: \.recents, action: \.recents) {
            RecentsFeature()
        }
        Scope(state: \.announcementBanner, action: \.announcementBanner) {
            AnnouncementBannerFeature()
        }
        Scope(state: \.whatsNewChecker, action: \.whatsNewChecker) {
            WhatsNewCheckerFeature()
        }
        Scope(state: \.maintenance, action: \.maintenance) {
            MaintenanceFeature()
        }
        CombineReducers {
            lifecycleAndObservationReducer
            recentsAndSharedPropertiesReducer
            requestsReducer
            connectionCardReducer
            destinationReducer
            miscReducer
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

private extension HomeFeature {
    var lifecycleAndObservationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .publisher {
                    state.$captureSession
                        .publisher
                        .receive(on: UIScheduler.shared)
                        .removeDuplicates()
                        .map(Action.newCaptureSession)
                }
                .cancellable(id: CancelID.captureSession)
            case .onDisappear:
                return .cancel(id: CancelID.captureSession)
            case .onStart:
                return .merge(
                    .send(.announcementBanner(.onStart)),
                    .send(.recents(.watchConnectionStatus)),
                    .send(.maintenance(.onStart)),
                    .run { send in
                        await send(.whatsNewChecker(.register))
                        try await clock.sleep(for: Self.whatsNewPresentationDelay)
                        await send(.whatsNewChecker(.check))
                    },
                    .run { send in
                        for await planChange in planChangeClient.events() {
                            await send(.planChanged(planChange))
                        }
                    }
                    .cancellable(id: CancelID.planChange),
                    // Refresh announcements now and whenever the app returns to the foreground
                    .send(.refreshAnnouncementsIfNeeded),
                    .publisher {
                        NotificationCenter.default
                            .publisher(for: didBecomeActiveNotification)
                            .receive(on: DispatchQueue.main)
                            .map { _ in Action.refreshAnnouncementsIfNeeded }
                    }
                    .cancellable(id: CancelID.announcementRefresh)
                )
                .cancellable(id: CancelID.connectionState)
            case let .newCaptureSession(captureSession):
                if case .sessionEnded = captureSession {
                    state.destination = .sessionCaptured(.init())
                } else if case .sessionCaptured = state.destination {
                    state.destination = nil
                }
                return .none
            case let .planChanged(planChange):
                // update the persisted feature settings so a downgrade clears paid features and an upgrade re-enables
                // NetShield.
                return .run { _ in applyPlanChangeFeatureResets(planChange) }
            case .refreshAnnouncementsIfNeeded:
                return .run { _ in
                    @SharedReader(.featureFlags) var featureFlags
                    guard featureFlags.pollNotificationAPI else { return }
                    announcementRefresher.tryRefreshing()
                }
            default:
                return .none
            }
        }
    }

    var recentsAndSharedPropertiesReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .recents(.delegate(.connect(spec, pinned))):
                let trigger: UserInitiatedVPNChange.VPNTrigger = pinned ? .pin : .recent
                connectionCommandClient.send(.connect(spec, nil, trigger))
                return .none
            case let .recents(.delegate(.upsellTapped(type))):
                state.destination = .payments(.init(upsellModalType: upsellModalType(from: type)))
                return .none
            default:
                return .none
            }
        }
    }

    /// Business logic for connection requests.
    var requestsReducer: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .changeServer:
                guard case .available = authorizer.serverChangeAvailability() else {
                    log.error("User is not authorized for server change, action should have been unavailable")
                    return .none
                }
                // Change Server is a free tier only action
                let spec = ConnectionSpec(location: .any(.random), features: [])
                connectionCommandClient.send(.connect(spec, nil, .changeServer))
                return .none

            case let .connectionFailed(error):
                return .send(.sharedProperties(.connectionFailed(error)))

            default:
                return .none
            }
        }
    }

    var connectionCardReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .connectionCard(.delegate(action)):
                switch action {
                case let .connect(spec):
                    connectionCommandClient.send(.connect(spec, nil, .connectionCard))
                    return .none
                case .disconnect:
                    connectionCommandClient.send(.disconnect(.connectionCard))
                    return .none
                case .tapAction:
                    if let detailsState = state.connectionState.connectionScreenFeatureState() {
                        state.destination = .connectionDetails(detailsState)
                    } else if userTier.isFree {
                        let freeCountries = Array(Set(
                            serverRepository.getServers(
                                filteredBy: [.tier(.exact(tier: .free))],
                                orderedBy: .nameAscending
                            ).map(\.logical.exitCountryCode)
                        ))

                        state.destination = .freeConnectionsInfo(.init(countryCodes: freeCountries))
                    }
                    return .none
                case .changeServerButtonTapped:
                    let availability = authorizer.serverChangeAvailability()
                    if case .available = availability {
                        return .send(.changeServer)
                    }
                    state.destination = .changeServer(.init(serverChangeAvailability: availability))
                    return .none
                case .defaultConnectionTapped:
                    state.destination = .defaultConnection(.init())
                    return .none
                }
            default:
                return .none
            }
        }
    }

    var destinationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.changeServer(buttonAction))):
                state.destination = nil
                switch buttonAction {
                case .upgradeButtonTapped:
                    state.shouldPushAlert = true
                    return .none
                case .changeServerButtonTapped:
                    return .send(.changeServer)
                }
            case .destination(.presented(.freeConnectionsInfo(.dismissButtonTapped))),
                 .destination(.presented(.defaultConnection(.preferenceSelected))),
                 .destination(.presented(.whatsNew(.dismissItem))):
                state.destination = nil
                return .none
            case .destination(.presented(.freeConnectionsInfo(.upgradeButtonTapped))):
                state.destination = .payments(.init(upsellModalType: .allCountries))
                return .none
            case .destination(.presented(.payments(.delegate(.completed)))),
                 .destination(.presented(.payments(.delegate(.dismissed)))):
                state.destination = nil
                return .none
            #if os(iOS)
                case .destination(.presented(.payments(.delegate(.createAccountFirstRequested)))):
                    state.destination = nil
                    return .run { @MainActor _ in
                        openCredentiallessSignUp()
                    }
            #endif
            default:
                return .none
            }
        }
    }

    var miscReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .whatsNewChecker(.show(items)):
                state.destination = .whatsNew(.init(item: items[0]))
                return .none
            case .didDismissChangeServer:
                if state.shouldPushAlert {
                    state.shouldPushAlert = false
                    state.destination = .payments(.init(upsellModalType: .allCountries))
                }
                return .none
            default:
                return .none
            }
        }
    }
}

extension LocalAgent.Stats {
    var toNetShieldModel: NetShield.NetShieldModel {
        NetShieldModel(
            trackersCount: Int(trackersBlocked ?? 0),
            adsCount: Int(adsBlocked ?? 0),
            dataSaved: dataSaved ?? 0,
            enabled: true
        )
    }
}

// MARK: - Destination.State Equatable Conformance

extension HomeFeature.Destination.State: Equatable {}
