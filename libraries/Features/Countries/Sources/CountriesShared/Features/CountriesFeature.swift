//
//  Created on 08/01/2026 by Max Kupetskyi.
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

import CommonNetworking
import ComposableArchitecture
import Dependencies
import Domain
import LegacyCommon
import Localization
import Modals
import ModalsShared
import PaymentsShared
import Persistence
import Strings
import VPNAppCore

@Reducer
public struct CountriesFeature {
    public init() {}

    @Reducer
    public enum Path {
        case search(SearchRoot)
        case country(CountryFeature)
    }

    @Reducer
    public enum Destination {
        case cityStateList(CityStateListFeature)
        case payments(PaymentsFeature)
        case serversFeaturesInfo(ServersFeaturesInformationFeature)
        case serversStreamingFeaturesInfo(ServersStreamingFeaturesFeature)
        case discourageSecureCoreView(DiscourageSecureCoreFeature)
        case freeConnectionsView(FreeConnectionsFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var path = StackState<Path.State>()
        public var sections: IdentifiedArrayOf<CountrySectionFeature.State>

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        @Shared(.secureCoreToggle) public var isSecureCore: Bool
        @SharedReader(.userTier) var userTier: Int?
        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

        public init(sections: IdentifiedArrayOf<CountrySectionFeature.State>) {
            self.sections = sections
        }

        public var isConnectedToVPN: Bool {
            vpnConnectionStatus.is(\.connected)
        }

        public var enableViewToggle: Bool {
            !vpnConnectionStatus.is(\.connecting)
        }
    }

    @CasePathable
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        case secureCoreToggleRequested
        case applySecureCoreToggle

        // navigation path
        case path(StackActionOf<Path>)

        // sheets
        case destination(PresentationAction<Destination.Action>)

        // alerts
        case alert(PresentationAction<Alert>)

        // Section actions
        case sections(IdentifiedActionOf<CountrySectionFeature>)

        // Navigation
        case showFeaturesInfo
        case showServersStreamingFeaturesInfo(countryName: String, services: [VpnStreamingOption])
        case showSearch

        // Upsell actions
        case presentAllCountriesUpsell
        case presentCountryUpsell(String)
        case presentFreeConnectionsInfo
        case presentSubscriptionManagement

        case connectRequested(ConnectionSpec, ConnectionProtocol?, UserInitiatedVPNChange.VPNTrigger?)
        case disconnectRequested(UserInitiatedVPNChange.VPNTrigger)

        @CasePathable
        public enum Alert {
            case disconnectAndToggle
            case cancel
        }
    }

    @SharedReader(.discourageSecureCore) private var discourageSecureCore: Bool
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.openCredentiallessSignUp) private var openCredentiallessSignUp
    @Dependency(\.connectToVPN) private var connectToVPN
    @Dependency(\.disconnectVPN) private var disconnectVPN
    @Dependency(\.switchToPrimaryTab) private var switchToPrimaryTab
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @Dependency(\.safeModePropertyProvider) private var safeModePropertyProvider
    @Dependency(\.natTypePropertyProvider) private var natTypePropertyProvider
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider

    public var body: some ReducerOf<Self> {
        CombineReducers {
            BindingReducer()
            alertAndSecureCoreReducer
            navigationAndUpsellReducer
            sectionInteractionReducer
            connectionReducer
            pathInteractionReducer
            destinationInteractionReducer
        }
        .forEach(\.path, action: \.path)
        .forEach(\.sections, action: \.sections) {
            CountrySectionFeature()
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Sub-Reducers

    /// Handles secure-core toggle flow and alert button actions.
    private var alertAndSecureCoreReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.cancel)):
                state.alert = nil
                return .none

            case .alert(.presented(.disconnectAndToggle)):
                state.alert = nil
                AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
                if state.isConnectedToVPN {
                    return .concatenate(
                        .send(.disconnectRequested(.countriesCountry)),
                        .send(.applySecureCoreToggle)
                    )
                }
                return .send(.applySecureCoreToggle)

            case .secureCoreToggleRequested:
                return handleSecureCoreToggleRequest(&state)

            case .applySecureCoreToggle:
                return .none

            case .alert:
                return .none

            default:
                return .none
            }
        }
    }

    /// Handles top-level navigation and upsell presentation intents.
    private var navigationAndUpsellReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .showFeaturesInfo:
                state.destination = .serversFeaturesInfo(ServersFeaturesInformationFeature.State.servicesInfo)
                return .none

            case let .showServersStreamingFeaturesInfo(countryName, services):
                state.destination = .serversStreamingFeaturesInfo(
                    .init(
                        countryName: countryName,
                        streamingServices: streamingServicesState(from: services)
                    )
                )
                return .none

            case .showSearch:
                state.path.append(.search(SearchRoot.State.loading(state.sections)))
                return .none

            case .presentAllCountriesUpsell:
                state.destination = .payments(
                    .init(
                        upsellModalType: .allCountries(
                            numberOfServers: serverRepository.roundedServerCount,
                            numberOfCountries: serverRepository.countryCount()
                        )
                    )
                )
                return .none

            case let .presentCountryUpsell(countryCode):
                state.destination = .payments(
                    .init(
                        upsellModalType: .country(
                            countryCode: countryCode,
                            numberOfDevices: DomainConstants.maxDeviceCount,
                            numberOfCountries: serverRepository.countryCount()
                        )
                    )
                )
                return .none

            case .presentFreeConnectionsInfo:
                state.destination = .freeConnectionsView(
                    .init(countries: freeCountries(from: state.sections))
                )
                return .none

            case .presentSubscriptionManagement:
                state.destination = .payments(
                    .init(presentationKind: .directSubscriptionManagement)
                )
                return .none

            default:
                return .none
            }
        }
    }

    /// Handles actions coming from section rows.
    /// This is where city/state list routing and row-level upsell logic live.
    private var sectionInteractionReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .sections(.element(id: .gateway, action: .delegate(.showGatewayInfo))):
                state.destination = .serversFeaturesInfo(ServersFeaturesInformationFeature.State.gatewaysInfo)
                return .none

            case .sections(.element(id: .freeProfiles, action: .delegate(.showFreeConnectionsInfo))):
                return .send(.presentFreeConnectionsInfo)

            case let .sections(.element(
                id: sectionID,
                action: .rows(.element(id: rowID, action: .country(.rowTapped)))
            )):
                guard let countryState = state.rowCountryState(sectionID: sectionID, rowID: rowID) else {
                    log.error("Country state not found for row: \(rowID)")
                    return .none
                }

                // Locked countries show country upsell first.
                if countryState.isUsersTierTooLow {
                    return .send(.presentCountryUpsell(countryState.countryCode))
                }

                // Standard country rows open city/state sheet; gateways and other
                // unsupported rows navigate directly to country detail.
                if shouldPresentCityStateList(countryState: countryState, isSecureCore: state.isSecureCore) {
                    state.destination = .cityStateList(.init(countryCode: countryState.countryCode))
                    return .none
                }
                state.path.append(.country(countryState))
                return .none

            case let .sections(.element(
                id: _,
                action: .rows(.element(id: _, action: .country(.showCountryUpsell(countryCode))))
            )):
                return .send(.presentCountryUpsell(countryCode))

            case .sections(.element(
                id: _,
                action: .rows(.element(id: _, action: .banner(.tapped)))
            )):
                return .send(.presentAllCountriesUpsell)

            case let .sections(.element(
                id: sectionID,
                action: .rows(.element(id: rowID, action: .country(.connectRequested(kind, serverType))))
            )):
                guard state.rowCountryState(sectionID: sectionID, rowID: rowID) != nil,
                      let connectionSpec = connectionSpec(for: kind, serverType: serverType) else {
                    return .none
                }
                return .send(.connectRequested(connectionSpec, nil, trigger(for: kind)))

            case let .sections(.element(id: sectionID, action: .rows(.element(id: rowID, action: .country(.disconnectRequested))))),
                 let .sections(.element(id: sectionID, action: .rows(.element(id: rowID, action: .country(.stopConnectingRequested))))):
                guard let countryState = state.rowCountryState(sectionID: sectionID, rowID: rowID),
                      let vpnTrigger = trigger(for: countryState.serverGroup.kind) else {
                    return .none
                }
                return .send(.disconnectRequested(vpnTrigger))

            case .sections(.element(id: _, action: .rows(.element(id: _, action: .country(.showMaintenanceAlert(_)))))):
                state.alert = maintenanceAlert
                return .none

            case .sections(.element(id: _, action: .rows(.element(id: _, action: .profile(.showProfilesUpsell))))):
                return .send(.presentSubscriptionManagement)

            case let .sections(.element(id: _, action: .rows(.element(id: _, action: .profile(.connectToProfile(profile)))))):
                return .send(.connectRequested(connectionSpec(for: profile), profile.connectionProtocol, .profile))

            case .sections(.element(id: _, action: .rows(.element(id: _, action: .profile(.disconnectRequested))))),
                 .sections(.element(id: _, action: .rows(.element(id: _, action: .profile(.stopConnectingRequested))))):
                return .send(.disconnectRequested(.profile))

            case .sections:
                return .none

            default:
                return .none
            }
        }
    }

    /// Handles connect/disconnect side effects and related telemetry/error reporting.
    private var connectionReducer: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case let .connectRequested(connectionSpec, connectionProtocol, trigger):
                .run { [connectToVPN, switchToPrimaryTab] _ in
                    try await connectToVPN(connectionSpec, connectionProtocol, trigger)
                    await switchToPrimaryTab()
                } catch: { error, _ in
                    log.error("Failed to connect from countries \(#file):\(#line) with error: \(error)")
                }

            case let .disconnectRequested(vpnTrigger):
                .run { [disconnectVPN] _ in
                    try await disconnectVPN(vpnTrigger)
                } catch: { error, _ in
                    log.error("Failed to disconnect from countries \(#file):\(#line) with error: \(error)")
                    SentryHelper.shared?.log(message: "Failed to disconnect from countries.", extra: [
                        "source": "CountriesFeature.disconnectRequested",
                        "trigger": "\(vpnTrigger)",
                        "error": "\(error)",
                    ])
                    SentryHelper.shared?.log(error: error)
                }

            default:
                .none
            }
        }
    }

    /// Handles actions bubbling from pushed navigation destinations (`path`):
    /// search results, country detail rows, and nested server actions.
    private var pathInteractionReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .path(.element(id: _, action: .search(.delegate(.showUpsell)))):
                return .send(.presentAllCountriesUpsell)

            case let .path(.element(id: _, action: .search(.delegate(.showCountryUpsell(countryCode))))):
                return .send(.presentCountryUpsell(countryCode))

            case let .path(.element(id: _, action: .search(.delegate(.navigateToCountry(countryCode))))):
                guard let countryState = state.countryState(for: countryCode) else {
                    return .none
                }
                state.path.append(.country(countryState))
                return .none

            case let .path(.element(id: _, action: .search(.delegate(.connectRequested(connectionSpec, trigger))))):
                return .send(.connectRequested(connectionSpec, nil, trigger))

            case let .path(.element(id: _, action: .country(.showCountryUpsell(countryCode)))):
                return .send(.presentCountryUpsell(countryCode))

            case let .path(.element(id: pathID, action: .country(.connectRequested(kind, serverType)))):
                guard state.path[id: pathID] != nil,
                      let connectionSpec = connectionSpec(for: kind, serverType: serverType) else {
                    return .none
                }
                return .send(.connectRequested(connectionSpec, nil, trigger(for: kind)))

            case let .path(.element(id: pathID, action: .country(.disconnectRequested))),
                 let .path(.element(id: pathID, action: .country(.stopConnectingRequested))):
                guard let countryState = pathCountryState(in: state.path, pathID: pathID),
                      let vpnTrigger = trigger(for: countryState.serverGroup.kind) else {
                    return .none
                }
                return .send(.disconnectRequested(vpnTrigger))

            case .path(.element(id: _, action: .country(.showMaintenanceAlert(_)))):
                state.alert = maintenanceAlert
                return .none

            case let .path(.element(
                id: _,
                action: .country(.serverSection(.element(id: _, action: .servers(.element(id: _, action: .connectRequested(server))))))
            )):
                return .send(.connectRequested(connectionSpec(for: server), nil, .countriesServer))

            case .path(.element(
                id: _,
                action: .country(.serverSection(.element(id: _, action: .servers(.element(id: _, action: .disconnectRequested)))))
            )),
            .path(.element(
                id: _,
                action: .country(.serverSection(.element(id: _, action: .servers(.element(id: _, action: .stopConnectingRequested)))))
            )):
                return .send(.disconnectRequested(.countriesServer))

            case .path(.element(
                id: _,
                action: .country(.serverSection(.element(id: _, action: .servers(.element(id: _, action: .showUpgradeUpsell)))))
            )):
                return .send(.presentSubscriptionManagement)

            case .path(.element(
                id: _,
                action: .country(.serverSection(.element(id: _, action: .servers(.element(id: _, action: .showMaintenanceAlert)))))
            )):
                state.alert = maintenanceAlert
                return .none

            case let .path(.element(
                id: pathID,
                action: .country(.serverSection(.element(id: sectionID, action: .servers(.element(id: serverID, action: .streamingInfoRequested)))))
            )):
                guard let countryState = pathCountryState(in: state.path, pathID: pathID),
                      let serverState = serverState(in: countryState, sectionID: sectionID, serverID: serverID),
                      serverState.isStreamingAvailable else {
                    return .none
                }
                return .send(.showServersStreamingFeaturesInfo(
                    countryName: countryState.countryName,
                    services: countryState.streamingServices
                ))

            case .path:
                return .none

            default:
                return .none
            }
        }
    }

    /// Handles callbacks emitted by presented sheets/full-screen destinations.
    private var destinationInteractionReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination(.presented(.discourageSecureCoreView(.delegate(.activateTapped)))):
                if state.isConnectedToVPN {
                    state.alert = disconnectAlert
                    return .none
                }
                return .send(.applySecureCoreToggle)

            case .destination(.presented(.cityStateList(.delegate(.dismissRequested)))):
                state.destination = nil
                return .none

            case .destination(.presented(.payments(.delegate(.completed)))),
                 .destination(.presented(.payments(.delegate(.dismissed)))):
                state.destination = nil
                return .none

            case .destination(.presented(.payments(.delegate(.createAccountFirstRequested)))):
                return .run { @MainActor [openCredentiallessSignUp] _ in
                    openCredentiallessSignUp()
                }

            case .destination(.presented(.freeConnectionsView(.upgradeTapped))):
                state.destination = nil
                return .send(.presentSubscriptionManagement)

            case .destination:
                return .none

            default:
                return .none
            }
        }
    }

    // MARK: - Private Helpers

    private func handleSecureCoreToggleRequest(_ state: inout State) -> Effect<Action> {
        let turningOn = !state.isSecureCore

        if turningOn {
            // Turning Secure Core ON

            // Check user tier
            if state.userTier?.isFreeTier == true {
                state.destination = .payments(.init(upsellModalType: .secureCore))
                return .none
            }

            // Check if we should show discourage view
            if discourageSecureCore {
                state.destination = .discourageSecureCoreView(.init())
                return .none
            }

            // Check if connected - need to disconnect
            if state.isConnectedToVPN {
                state.alert = disconnectAlert
                return .none
            }

            // All checks passed, apply toggle
            return .send(.applySecureCoreToggle)
        } else {
            // Turning Secure Core OFF

            // Check if connected - need to disconnect
            if state.isConnectedToVPN {
                state.alert = disconnectAlert
                return .none
            }

            // Apply toggle directly
            return .send(.applySecureCoreToggle)
        }
    }

    private var disconnectAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.warning) },
            actions: {
                ButtonState(
                    action: .send(.disconnectAndToggle),
                    label: { TextState(Localizable.continue) }
                )
                ButtonState(
                    role: .cancel,
                    action: .send(.cancel),
                    label: { TextState(Localizable.cancel) }
                )
            },
            message: { TextState(Localizable.viewToggleWillCauseDisconnect) }
        )
    }

    private var maintenanceAlert: AlertState<Action.Alert> {
        AlertState { TextState(Localizable.serverUnderMaintenance) }
    }

    /// Maps server-group kinds to disconnect/connect telemetry triggers.
    /// Country and gateway share `.country` here for parity with legacy analytics.
    private func trigger(for kind: ServerGroupInfo.Kind) -> UserInitiatedVPNChange.VPNTrigger? {
        switch kind {
        case .country, .gateway:
            .country
        case .city:
            .countriesCity
        case .state:
            .countriesState
        }
    }

    /// City/state sheet is available only for standard country rows.
    /// Secure-core and gateways keep the detail-navigation flow.
    private func shouldPresentCityStateList(
        countryState: CountryFeature.State,
        isSecureCore: Bool
    ) -> Bool {
        guard !isSecureCore,
              !countryState.isGateway else {
            return false
        }
        if case .country = countryState.serverGroup.kind {
            return true
        }
        return false
    }

    /// Builds connection target for country rows.
    /// Secure-core country rows need a secure-core hop spec, while standard rows
    /// use direct country/city/state/gateway locations.
    private func connectionSpec(for kind: ServerGroupInfo.Kind, serverType: ServerType) -> ConnectionSpec? {
        let location: ConnectionSpec.Location = switch kind {
        case let .country(code):
            if serverType == .secureCore {
                .secureCore(.anyHop(to: code, .fastest))
            } else {
                .country(code: code, order: .fastest)
            }
        case let .city(name, code):
            .city(name: name, code: code, order: .fastest)
        case let .state(name, code):
            .state(name: name, code: code, order: .fastest)
        case let .gateway(name):
            .gateway(name: name)
        }

        return .init(location: location, features: [])
    }

    /// Builds connection target for explicit server selections from country detail.
    private func connectionSpec(for server: VPNServer) -> ConnectionSpec {
        .init(
            location: .exact(
                server.logical.tier.isFreeTier ? .free : .paid,
                logicalID: server.logical.id,
                number: server.logical.serverNameComponents.sequence,
                subregion: server.logical.city,
                regionCode: server.logical.exitCountryCode
            ),
            features: []
        )
    }

    /// Profiles rely on current defaults (NetShield, NAT, Safe Mode, Port Forwarding),
    /// so we build the connection request from profile + current settings each time.
    private func connectionSpec(for profile: Profile) -> ConnectionSpec {
        let connectionRequest = profile.connectionRequest(
            withDefaultNetshield: netShieldPropertyProvider.getNetShieldType(),
            withDefaultNATType: natTypePropertyProvider.getNATType(),
            withDefaultSafeMode: safeModePropertyProvider.getSafeMode(),
            withDefaultPortForwarding: portForwardingPropertyProvider.getPortForwarding(),
            trigger: .profile
        )
        return ConnectionSpec(connectionRequest: connectionRequest)
    }

    private func pathCountryState(
        in path: StackState<Path.State>,
        pathID: StackElementID
    ) -> CountryFeature.State? {
        guard let pathState = path[id: pathID],
              case let .country(countryState) = pathState else {
            return nil
        }
        return countryState
    }

    private func serverState(
        in countryState: CountryFeature.State,
        sectionID: String,
        serverID: String
    ) -> ServerItemFeature.State? {
        countryState.serverSections[id: sectionID]?.servers[id: serverID]
    }

    private func streamingServicesState(from services: [VpnStreamingOption]) -> IdentifiedArrayOf<StreamingServiceItem.State> {
        IdentifiedArray(uniqueElements: services.map {
            StreamingServiceItem.State(service: $0, showImage: true)
        })
    }

    private func freeCountries(
        from sections: IdentifiedArrayOf<CountrySectionFeature.State>
    ) -> IdentifiedArrayOf<FreeConnectionsFeature.State.Country> {
        var seenCodes = Set<String>()
        var countries: [FreeConnectionsFeature.State.Country] = []

        for section in sections {
            for row in section.rows {
                guard case let .country(countryState) = row,
                      case let .country(code) = countryState.serverGroup.kind,
                      countryState.serverGroup.minTier.isFreeTier,
                      !seenCodes.contains(code) else {
                    continue
                }

                seenCodes.insert(code)
                countries.append(.init(
                    code: code,
                    name: LocalizationUtility.default.countryName(forCode: code) ?? Localizable.unavailable
                ))
            }
        }

        return IdentifiedArray(uniqueElements: countries)
    }
}

extension CountriesFeature.State {
    func rowCountryState(sectionID: CountrySectionFeature.SectionID, rowID: String) -> CountryFeature.State? {
        guard let row = sections[id: sectionID]?.rows[id: rowID],
              case let .country(countryState) = row else {
            return nil
        }
        return countryState
    }

    func countryState(for countryCode: String) -> CountryFeature.State? {
        for section in sections {
            for row in section.rows {
                guard case let .country(countryState) = row else {
                    continue
                }
                if countryState.countryCode == countryCode {
                    return countryState
                }
            }
        }
        return nil
    }
}

// MARK: - Path.State Equatable Conformance

extension CountriesFeature.Path.State: Equatable {}

extension CountriesFeature.Destination.State: Equatable {}
