//
//  CreateNewProfileViewModel.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa

import Domain
import Strings
import Theme
import LegacyCommon
import VPNShared
import VPNAppCore
import Persistence
import Dependencies

protocol CreateNewProfileViewModelFactory {
    func makeCreateNewProfileViewModel(editProfile: Notification.Name) -> CreateNewProfileViewModel
}

extension DependencyContainer: CreateNewProfileViewModelFactory {
    func makeCreateNewProfileViewModel(editProfile: Notification.Name) -> CreateNewProfileViewModel {
        return CreateNewProfileViewModel(editProfile: editProfile, factory: self)
    }
}

class CreateNewProfileViewModel {
    
    typealias Factory = CoreAlertServiceFactory &
        VpnKeychainFactory &
        PropertiesManagerFactory &
        AppStateManagerFactory &
        VpnGatewayFactory &
        ProfileManagerFactory &
        SystemExtensionManagerFactory &
        SessionServiceFactory
    private let factory: Factory
    
    typealias MenuContentUpdate = Set<KeyPath<CreateNewProfileViewModel, [PopUpButtonItemViewModel]>>

    var menuContentChanged: ((MenuContentUpdate) -> Void)?
    var prefillContent: (() -> Void)?
    var protocolPending: ((Bool) -> Void)?
    var sysexTourCancelled: (() -> Void)?

    var contentWarning: ((String) -> Void)?

    var secureCoreWarning: (() -> Void)?
    var alreadyPresentedSecureCoreWarning = false

    let sessionFinished = NSNotification.Name("CreateNewProfileViewModelSessionFinished") // two observers

    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    private let propertiesManager: PropertiesManagerProtocol
    @Dependency(\.serverRepository) private var serverRepository

    let colorPickerViewModel = ColorPickerViewModel()
    lazy var secureCoreWarningViewModel = SecureCoreWarningViewModel(sessionService: factory.makeSessionService())

    private var userTier: Int = .paidTier
    private var profileId: String?
    private var state: ModelState {
        didSet {
            if oldValue.connectionProtocol != state.connectionProtocol {
                checkSystemExtensionOrResetProtocol(newProtocol: state.connectionProtocol, shouldStartTour: false)
            }
            if let contentUpdate = oldValue.menuContentUpdate(forNewValue: state) {
                menuContentChanged?(contentUpdate)
            }
        }
    }

    /// Consults the server repository and properties manager to create an empty/starting model state.
    /// We could make this a static initializer on `ModelState` since we now have `@Dependency(\.propertiesManager)` and
    /// `@Dependency(\.serverRepository)`, but it's probably not worth getting carried away with non-essential refactors
    /// on viewmodels that will be removed during redesign.
    private func createStartingState() -> ModelState {
        let defaultServerType = ModelState.default.serverType
        var connectionProtocol = propertiesManager.connectionProtocol
        // If IKEv2 is the user's selected protocol, we will switch to smart protocol instead.
        if connectionProtocol == .vpnProtocol(.ike) {
            connectionProtocol = .smartProtocol
        }
        
        return ModelState.default
            .updating(
                serverType: defaultServerType,
                newTypeGrouping: serverGroups(for: defaultServerType),
                selectedCountryGroup: nil,
                smartProtocolConfig: propertiesManager.smartProtocolConfig
            )
            .updating(connectionProtocol: connectionProtocol)
    }

    // MARK: Getters derived from model state

    var profileName: String? {
        get {
            state.profileName
        }
        set {
            state = ModelState(profileName: newValue,
                               serverType: state.serverType,
                               serverGroups: state.serverGroups,
                               countryIndex: state.countryIndex,
                               serverOffering: state.serverOffering,
                               connectionProtocol: state.connectionProtocol)
        }
    }

    // MARK: Menu items

    var serverTypeMenuItems: [PopUpButtonItemViewModel] {
        ServerType.humanReadableCases.map { item in
                .init(title: menuStyle(item.localizedString),
                      checked: state.serverType == item,
                      handler: { [weak self] in self?.update(type: item) })
        }
    }

    // Filter currently available servers by their type: standard, secure core, p2p, tor
    private func serverGroups(for type: ServerType) -> [ServerGroupInfo] {
        return serverRepository.getGroups(filteredBy: [.features(type.serverTypeFilter)])
    }

    /// Contains one placeholder item at the beginning, followed by all available countries.
    var countryMenuItems: [PopUpButtonItemViewModel] {
        // Placeholder item
        [PopUpButtonItemViewModel(
            title: menuStyle(Localizable.selectCountry),
            checked: state.countryIndex == nil,
            handler: { [weak self] in self?.update(countryIndex: nil) }
        )] +
        // Countries by index in their grouping
        state.serverGroups.enumerated().map { (index, grouping) in
            PopUpButtonItemViewModel(
                title: countryDescriptor(for: grouping),
                checked: state.countryIndex == index,
                handler: { [weak self] in self?.update(countryIndex: index) }
            )
        }
    }

    /// Helper function to get the list of servers according to a group (country) selected
    private var currentGroupServers: [ServerInfo]? {
        guard let countryGroup = state.selectedGroup else {
            return nil
        }
        let supportedProtocols = state.connectionProtocol?.vpnProtocol != nil
            ? [state.connectionProtocol!.vpnProtocol!]
            : propertiesManager.smartProtocolConfig.supportedProtocols

        return serverRepository.getServers(
            filteredBy: [
                .features(state.serverType.serverTypeFilter), // Standard / Secure Core / P2P / TOR
                .supports(protocol: ProtocolSupport(vpnProtocols: supportedProtocols)), // Only the ones supporting selected protocol
                .kind(countryGroup.kind.serverTypeFilter), // Only from selected country/gateway
            ],
            orderedBy: .nameAscending
        )
    }

    /// Contains one placeholder item at the beginning. If a country is selected, the placeholder will
    /// be followed by the `fastest` offering, the `random` offering, and then the list of all servers
    /// for that country.
    var serverMenuItems: [PopUpButtonItemViewModel] {
        var result = [PopUpButtonItemViewModel]()

        // Placeholder
        result += [PopUpButtonItemViewModel(
            title: menuStyle(Localizable.selectServer),
            checked: state.serverOffering == nil,
            handler: { [weak self] in self?.update(serverOffering: nil) }
        )]

        guard let group = state.selectedGroup else { return result }

        if case .country = group.kind {
            // Add default "profiles": fastest and random (only for countries, not gateways)
            result += [
                ServerOffering.fastest(group.serverOfferingID),
                ServerOffering.random(group.serverOfferingID)
            ].map { offering in
                PopUpButtonItemViewModel(
                    title: serverDescriptor(for: offering),
                    checked: state.serverOffering == offering,
                    handler: { [weak self] in self?.update(serverOffering: offering) }
                )
            }
        }

        guard let currentGroupServers else {
            return result
        }

        // List all available servers
        result += currentGroupServers.map { server in
            var checked = false
            if case .custom(let selectedServerWrapper) = state.serverOffering {
                checked = selectedServerWrapper.server.id == server.logical.id
            }

            return PopUpButtonItemViewModel(
                title: serverDescriptor(for: server),
                checked: checked,
                handler: { [weak self] in
                    // Now that we don't load whole objects from the repository, it became
                    // not effective to pre-fill ServerOffering objects before one is selected,
                    // so we do it here, only for the selected object.
                    if let vpnServer = self?.serverRepository.getFirstServer(
                            filteredBy: [.logicalID(server.logical.id)],
                            orderedBy: .fastest) {
                        let serverModel = ServerModel(server: vpnServer)
                        let offering = ServerOffering.custom(ServerWrapper(server: serverModel))
                        self?.update(serverOffering: offering)
                    } else {
                        log.error("No server found with ID \(server.logical.id)", category: .persistence)
                    }
                }
            )
        }

        return result
    }

    /// If the selected offering does not support a given protocol or a required feature flag is disabled,
    /// the protocol list will not show it. If the selected protocol requires a system extension, and that
    /// extension is not installed or unavailable, it will be switched to one that doesn't require one.
    var protocolMenuItems: [PopUpButtonItemViewModel] {
        ConnectionProtocol.availableProtocols(wireguardTLSEnabled: propertiesManager.featureFlags.wireGuardTls)
            .sorted(by: ConnectionProtocol.uiSort)
            .filter { `protocol` in
                state.serverOffering?.supports(
                    connectionProtocol: `protocol`,
                    withCountryGroup: state.selectedGroup,
                    smartProtocolConfig: propertiesManager.smartProtocolConfig
                ) != false
            }.map { `protocol` in
                PopUpButtonItemViewModel(
                    title: menuStyle(`protocol`.localizedString),
                    checked: `protocol` == state.connectionProtocol,
                    handler: { [weak self] in self?.update(connectionProtocol: `protocol`, userInitiated: true) }
                )
            }
    }

    // MARK: Helper functions and initialization

    private func menuStyle(_ string: String) -> NSAttributedString {
        style(string, font: .themeFont(.heading4), alignment: .left)
    }

    var userTierSupportsSecureCore: Bool {
        userTier.isPaidTier
    }

    func userTierSupports(group: ServerGroupInfo) -> Bool {
        group.minTier <= userTier
    }

    func userTierSupports(server: ServerModel) -> Bool {
        userTierSupports(serverWithTier: server.tier)
    }

    func userTierSupports(serverWithTier tier: Int) -> Bool {
        tier <= userTier
    }

    private func setupUserTier() {
        do {
            userTier = try vpnKeychain.fetchCached().maxTier
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
        }
    }

    init(editProfile: Notification.Name, factory: Factory) {
        self.factory = factory

        let propertiesManager = factory.makePropertiesManager()
        self.propertiesManager = propertiesManager

        self.state = ModelState.default // initialize all stored properties so we can use createStartingState
        self.state = self.createStartingState()

        // Check is required here, as the didSet check is not invoked when assigning inside the constructor
        checkSystemExtensionOrResetProtocol(newProtocol: state.connectionProtocol, shouldStartTour: true)

        setupUserTier()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(editProfile(_:)),
                                               name: editProfile,
                                               object: nil)
    }

    // MARK: Updating state

    private func update(type: ServerType) {
        if type == .secureCore && !userTierSupportsSecureCore && !alreadyPresentedSecureCoreWarning {
            secureCoreWarning?()
            alreadyPresentedSecureCoreWarning = true
        }

        state = state.updating(serverType: type,
                               newTypeGrouping: serverGroups(for: type),
                               selectedCountryGroup: state.selectedGroup,
                               smartProtocolConfig: propertiesManager.smartProtocolConfig)
    }

    private func update(countryIndex: Int?) {
        state = state.updating(countryIndex: countryIndex,
                               selectedCountryGroup: state.selectedGroup,
                               smartProtocolConfig: propertiesManager.smartProtocolConfig)
    }

    private func update(serverOffering: ServerOffering?) {
        state = state.updating(serverOffering: serverOffering,
                               selectedCountryGroup: state.selectedGroup,
                               smartProtocolConfig: propertiesManager.smartProtocolConfig)
    }

    /// Starts the system extension tour if system extensions are required for `connection protocol` but are not enabled
    private func update(connectionProtocol: ConnectionProtocol?, userInitiated: Bool = false) {

        checkSystemExtensionOrResetProtocol(newProtocol: connectionProtocol, shouldStartTour: true)
        state = state.updating(connectionProtocol: connectionProtocol)

        if connectionProtocol == .vpnProtocol(.ike) && userInitiated {
            self.alertService.push(alert: IkeDeprecatedAlert(enableSmartProtocolHandler: { [weak self] in
                guard let self = self else {
                    return
                }
                SentryHelper.shared?.log(message: "IKEv2 Deprecation: User accepted to switch to Smart protocol for a new profile.")
                self.update(connectionProtocol: .smartProtocol)
            }, continueHandler: {
                SentryHelper.shared?.log(message: "IKEv2 Deprecation: User decided to continue with IKEv2 anyway for a new profile.")
            }))
        }
    }

    func clearContent() {
        state = createStartingState()
        profileId = nil
        colorPickerViewModel.select(index: 0)
        NotificationCenter.default.post(name: sessionFinished, object: nil)
    }

    // MARK: System extensions

    private func checkSystemExtensionOrResetProtocol(newProtocol: ConnectionProtocol?, shouldStartTour: Bool) {
        guard newProtocol?.requiresSystemExtension == true else {
            return
        }

        let resetProtocol = { [weak self] in
            guard let `self` else { return }
            self.state = self.state.updating(connectionProtocol: .vpnProtocol(.ike))
            self.protocolPending?(false)
        }

        protocolPending?(true)
        sysexTourCancelled = resetProtocol

        sysexManager.installOrUpdateExtensionsIfNeeded(shouldStartTour: shouldStartTour) { result in
            DispatchQueue.main.async { [weak self] in
                guard let `self` else { return }

                self.protocolPending?(false)
                switch result {
                case .failure(let error):
                    // In the future, we should tell the user when we're setting the protocol because
                    // we aren't in the /Applications folder.
                    log.warning("Resetting protocol due to sysex failure", metadata: ["error": "\(error)"])
                    resetProtocol()
                case .success:
                    break
                }
            }
        }
    }

    // MARK: Populate fields from an existing profile, or save it to the profile manager

    @objc private func editProfile(_ notification: Notification) {
        if let profile = notification.object as? Profile {
            prefillInfo(for: profile)
        }
    }

    private func prefillInfo(for profile: Profile) {
        guard profile.profileType == .user, case ProfileIcon.circle(let color) = profile.profileIcon else {
            return
        }

        let grouping: [ServerGroupInfo]
        grouping = serverRepository.getGroups(filteredBy: [.features(state.serverType.serverTypeFilter)])

        var connectionProtocol: ConnectionProtocol? = profile.connectionProtocol

        var countryIndex: Int?
        if profile.serverOffering.countryCode != nil {
            countryIndex = grouping.firstIndex {
                switch $0.kind {
                case .country(let countryCode):
                    return countryCode == profile.serverOffering.countryCode
                case .gateway(let name):
                    return name == profile.serverOffering.countryCode
                }
            }

            if let countryIndex, connectionProtocol != nil,
               !profile.serverOffering.supports(connectionProtocol: connectionProtocol!,
                                                withCountryGroup: grouping[countryIndex],
                                                smartProtocolConfig: propertiesManager.smartProtocolConfig) {
                connectionProtocol = nil
            }
        }

        colorPickerViewModel.select(rgbHex: color)
        profileId = profile.id

        state = ModelState(profileName: profile.name,
                           serverType: profile.serverType,
                           serverGroups: grouping,
                           countryIndex: countryIndex,
                           serverOffering: profile.serverOffering,
                           connectionProtocol: connectionProtocol)

        prefillContent?() // tell the view controller to fill in non-menu things (like the name)
    }

    func save() {
        var errors: [String] = []
        if profileName?.isEmpty != false {
            errors.append(Localizable.profileNameIsRequired)
        }
        if (profileName?.count ?? 0) > 25 {
            errors.append(Localizable.profileNameIsTooLong)
        }
        if state.countryIndex == nil {
            errors.append(Localizable.countrySelectionIsRequired)
        }
        if state.serverOffering == nil {
            errors.append(Localizable.serverSelectionIsRequired)
        }
        guard errors.isEmpty else {
            contentWarning?(errors.joined(separator: ", "))
            return
        }

        createProfile()
    }

    func createProfile() {
        guard let name = profileName,
              let selectedGroup = state.selectedGroup,
              let connectionProtocol = state.connectionProtocol,
              let serverOffering = state.serverOffering else {
            return
        }

        let profileId = profileId ?? .randomString(length: Profile.idLength)

        let accessTier: Int
        switch serverOffering {
        case .fastest, .random:
            accessTier = selectedGroup.minTier
        case .custom(let wrapper):
            accessTier = wrapper.server.tier
        }

        let profile = Profile(id: profileId,
                              accessTier: accessTier,
                              profileIcon: .circle(colorPickerViewModel.selectedColor.hexRepresentation),
                              profileType: .user,
                              serverType: state.serverType,
                              serverOffering: serverOffering,
                              name: name,
                              connectionProtocol: connectionProtocol)

        let result = self.profileId != nil ?
            profileManager.updateProfile(profile) :
            profileManager.createProfile(profile)

        switch result {
        case .success:
            clearContent()
        case .nameInUse:
            contentWarning?(Localizable.profileNameNeedsToBeUnique)
        }
    }
}

extension CreateNewProfileViewModel: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .text:
            return .dropdown
        case .field, .icon:
            return .normal
        case .border, .background:
            return .weak
        }
    }
}

fileprivate struct ModelState {
    let profileName: String?
    let serverType: ServerType
    let serverGroups: [ServerGroupInfo]
    let countryIndex: Int?
    let serverOffering: ServerOffering?
    let connectionProtocol: ConnectionProtocol?

    static let `default` = Self(profileName: nil,
                                serverType: .standard,
                                serverGroups: [],
                                countryIndex: nil,
                                serverOffering: nil,
                                connectionProtocol: nil)
}

/// Editing a profile uses 4 menus, containing the server type, country, server, and protocol.
/// Changing the first element can potentially impact subsequent ones.
/// These update functions call one other in a tree, according to which updates may impact other selected values.
extension ModelState {
    func updating(serverType: ServerType,
                  newTypeGrouping: [ServerGroupInfo],
                  selectedCountryGroup: ServerGroupInfo?,
                  smartProtocolConfig: SmartProtocolConfig) -> Self {

        // Re-select country/gateway if it's still there after ServerType change
        let countryIndex = newTypeGrouping.firstIndex { $0.kind == selectedCountryGroup?.kind }

        return ModelState(profileName: self.profileName,
                          serverType: serverType,
                          serverGroups: newTypeGrouping,
                          countryIndex: self.countryIndex,
                          serverOffering: self.serverOffering,
                          connectionProtocol: self.connectionProtocol)
            .updating(countryIndex: countryIndex,
                      selectedCountryGroup: selectedCountryGroup,
                      smartProtocolConfig: smartProtocolConfig)
    }

    func updating(countryIndex: Int?,
                  selectedCountryGroup: ServerGroupInfo?,
                  smartProtocolConfig: SmartProtocolConfig) -> Self {
        var serverOffering = serverOffering
        if self.countryIndex != countryIndex {
            serverOffering = nil
        }

        return ModelState(profileName: self.profileName,
                          serverType: self.serverType,
                          serverGroups: self.serverGroups,
                          countryIndex: countryIndex,
                          serverOffering: self.serverOffering,
                          connectionProtocol: self.connectionProtocol)
            .updating(serverOffering: serverOffering,
                      selectedCountryGroup: selectedCountryGroup,
                      smartProtocolConfig: smartProtocolConfig)
    }

    func updating(serverOffering: ServerOffering?,
                  selectedCountryGroup: ServerGroupInfo?,
                  smartProtocolConfig: SmartProtocolConfig) -> Self {
        var connectionProtocol = connectionProtocol
        if self.serverOffering != serverOffering,
           let serverOffering,
           connectionProtocol != nil,
           !serverOffering.supports(connectionProtocol: connectionProtocol!,
                                    withCountryGroup: selectedCountryGroup,
                                    smartProtocolConfig: smartProtocolConfig) {
            connectionProtocol = nil
        }

        return ModelState(profileName: self.profileName,
                          serverType: self.serverType,
                          serverGroups: self.serverGroups,
                          countryIndex: self.countryIndex,
                          serverOffering: serverOffering,
                          connectionProtocol: self.connectionProtocol)
            .updating(connectionProtocol: connectionProtocol)
    }

    func updating(connectionProtocol: ConnectionProtocol?) -> Self {
        Self(profileName: self.profileName,
             serverType: self.serverType,
             serverGroups: self.serverGroups,
             countryIndex: self.countryIndex,
             serverOffering: self.serverOffering,
             connectionProtocol: connectionProtocol)
    }

    var selectedGroup: ServerGroupInfo? {
        guard let countryIndex = countryIndex, countryIndex >= 0 && countryIndex < serverGroups.count else {
            return nil
        }
        return serverGroups[countryIndex]
    }

    func menuContentUpdate(forNewValue newValue: Self) -> CreateNewProfileViewModel.MenuContentUpdate? {
        var result: CreateNewProfileViewModel.MenuContentUpdate = []

        // Even if the selected value hasn't changed, the contents of the menus may have.
        if newValue.serverType != serverType {
            result.insert(\.serverTypeMenuItems)
            result.insert(\.countryMenuItems)
            result.insert(\.serverMenuItems)
            result.insert(\.protocolMenuItems)
            return result
        }
        if newValue.countryIndex != countryIndex {
            result.insert(\.countryMenuItems)
            result.insert(\.serverMenuItems)
            result.insert(\.protocolMenuItems)
            return result
        }
        if newValue.serverOffering != serverOffering {
            result.insert(\.serverMenuItems)
            result.insert(\.protocolMenuItems)
            return result
        }
        if newValue.connectionProtocol != connectionProtocol {
            result.insert(\.protocolMenuItems)
            return result
        }
        return nil
    }
}
