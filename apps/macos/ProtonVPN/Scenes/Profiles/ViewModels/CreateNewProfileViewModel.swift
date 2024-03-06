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
        SessionServiceFactory &
        ServerStorageFactory
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

    private lazy var serverManager: ServerManager =
        ServerManagerImplementation.instance(forTier: userTier,
                                             serverStorage: factory.makeServerStorage())
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    private let propertiesManager: PropertiesManagerProtocol

    let colorPickerViewModel = ColorPickerViewModel()
    lazy var secureCoreWarningViewModel = SecureCoreWarningViewModel(sessionService: factory.makeSessionService())

    private var userTier: Int = CoreAppConstants.VpnTiers.internal
    private var profileId: String?
    private var state: ModelState {
        didSet {
            checkSystemExtensionOrResetProtocol(newProtocol: state.connectionProtocol, shouldStartTour: false)
            if let contentUpdate = oldValue.menuContentUpdate(forNewValue: state) {
                menuContentChanged?(contentUpdate)
            }
        }
    }

    // MARK: Getters derived from model state

    var selectedServerGrouping: [ServerGroup] {
        serverManager.grouping(for: state.serverType)
    }

    var selectedCountryGroup: ServerGroup? {
        guard let countryIndex = state.countryIndex else {
            return nil
        }
        return selectedServerGrouping[countryIndex]
    }

    var profileName: String? {
        get {
            state.profileName
        }
        set {
            state = ModelState(profileName: newValue,
                               serverType: state.serverType,
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

    /// Contains one placeholder item at the beginning, followed by all available countries.
    var countryMenuItems: [PopUpButtonItemViewModel] {
        // Placeholder item
        [PopUpButtonItemViewModel(
            title: menuStyle(Localizable.selectCountry),
            checked: state.countryIndex == nil,
            handler: { [weak self] in self?.update(countryIndex: nil) }
        )] +
        // Countries by index in their grouping
        serverManager.grouping(for: state.serverType).enumerated().map { (index, grouping) in
            PopUpButtonItemViewModel(
                title: countryDescriptor(for: grouping),
                checked: state.countryIndex == index,
                handler: { [weak self] in self?.update(countryIndex: index) }
            )
        }
    }

    /// Contains one placeholder item at the beginning. If a country is selected, the placeholder will
    /// be followed by the `fastest` offering, the `random` offering, and then the list of all servers
    /// for that country.
    var serverMenuItems: [PopUpButtonItemViewModel] {
        let placeholder: PopUpButtonItemViewModel =
        PopUpButtonItemViewModel(
            title: menuStyle(Localizable.selectServer),
            checked: state.serverOffering == nil,
            handler: { [weak self] in self?.update(serverOffering: nil) }
        )

        guard let group = selectedCountryGroup else { return [placeholder] }

        let offerings: [ServerOffering] = [.fastest(group.serverOfferingId), .random(group.serverOfferingId)]
            + group.servers.map { .custom(.init(server: $0)) }

        return [placeholder]
            + offerings.map { offering in
                PopUpButtonItemViewModel(title: serverDescriptor(for: offering),
                      checked: state.serverOffering == offering,
                      handler: { [weak self] in self?.update(serverOffering: offering) })
            }
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
                    withCountryGroup: selectedCountryGroup,
                    smartProtocolConfig: propertiesManager.smartProtocolConfig
                ) != false
            }.map { `protocol` in
                PopUpButtonItemViewModel(
                    title: menuStyle(`protocol`.localizedString),
                    checked: `protocol` == state.connectionProtocol,
                    handler: { [weak self] in self?.update(connectionProtocol: `protocol`) }
                )
            }
    }

    // MARK: Helper functions and initialization

    private func menuStyle(_ string: String) -> NSAttributedString {
        style(string, font: .themeFont(.heading4), alignment: .left)
    }

    var userTierSupportsSecureCore: Bool {
        CoreAppConstants.VpnTiers.plus <= userTier
    }

    func userTierSupports(group: ServerGroup) -> Bool {
        group.kind.lowestTier <= userTier
    }

    func userTierSupports(server: ServerModel) -> Bool {
        server.tier <= userTier
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
        self.state = .default
            .updating(connectionProtocol: propertiesManager.connectionProtocol)

        // Check is required here, as the didSet check is not invoked when assigning inside the constructor
        checkSystemExtensionOrResetProtocol(newProtocol: state.connectionProtocol, shouldStartTour: false)

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
                               newTypeGrouping: serverManager.grouping(for: type),
                               selectedCountryGroup: selectedCountryGroup,
                               smartProtocolConfig: propertiesManager.smartProtocolConfig)
    }

    private func update(countryIndex: Int?) {
        state = state.updating(countryIndex: countryIndex,
                               selectedCountryGroup: selectedCountryGroup,
                               smartProtocolConfig: propertiesManager.smartProtocolConfig)
    }

    private func update(serverOffering: ServerOffering?) {
        state = state.updating(serverOffering: serverOffering,
                               selectedCountryGroup: selectedCountryGroup,
                               smartProtocolConfig: propertiesManager.smartProtocolConfig)
    }

    /// Starts the system extension tour if system extensions are required for `connection protocol` but are not enabled
    private func update(connectionProtocol: ConnectionProtocol?) {
        checkSystemExtensionOrResetProtocol(newProtocol: connectionProtocol, shouldStartTour: true)

        state = state.updating(connectionProtocol: connectionProtocol)
    }

    func clearContent() {
        state = .default
            .updating(connectionProtocol: propertiesManager.connectionProtocol)
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
                case .failure:
                    // In the future, we should tell the user when we're setting the protocol because
                    // we aren't in the /Applications folder.
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

        let grouping = serverManager.grouping(for: profile.serverType)
        var connectionProtocol: ConnectionProtocol? = profile.connectionProtocol

        var countryIndex: Int?
        if profile.serverOffering.countryCode != nil {
            countryIndex = grouping.firstIndex {
                switch $0.kind {
                case .country(let country):
                    return country.countryCode == profile.serverOffering.countryCode
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
              let selectedCountryGroup,
              let connectionProtocol = state.connectionProtocol,
              let serverOffering = state.serverOffering else {
            return
        }

        let profileId = profileId ?? .randomString(length: Profile.idLength)

        let accessTier: Int
        switch serverOffering {
        case .fastest, .random:
            accessTier = selectedCountryGroup.kind.lowestTier
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
    let countryIndex: Int?
    let serverOffering: ServerOffering?
    let connectionProtocol: ConnectionProtocol?

    static let `default` = Self(profileName: nil,
                                serverType: .standard,
                                countryIndex: nil,
                                serverOffering: nil,
                                connectionProtocol: nil)
}

/// Editing a profile uses 4 menus, containing the server type, country, server, and protocol.
/// Changing the first element can potentially impact subsequent ones.
/// These update functions call one other in a tree, according to which updates may impact other selected values.
extension ModelState {
    func updating(serverType: ServerType,
                  newTypeGrouping: [ServerGroup],
                  selectedCountryGroup: ServerGroup?,
                  smartProtocolConfig: SmartProtocolConfig) -> Self {
        var countryIndex = countryIndex

        // Re-select country/gateway if it's still there after ServerType change
        if let selectedGroupCode = selectedCountryGroup?.serverOfferingId {
            countryIndex = newTypeGrouping.firstIndex { $0.serverOfferingId == selectedGroupCode }
        }

        return ModelState(profileName: self.profileName,
                          serverType: serverType,
                          countryIndex: self.countryIndex,
                          serverOffering: self.serverOffering,
                          connectionProtocol: self.connectionProtocol)
            .updating(countryIndex: countryIndex,
                      selectedCountryGroup: selectedCountryGroup,
                      smartProtocolConfig: smartProtocolConfig)
    }

    func updating(countryIndex: Int?,
                  selectedCountryGroup: ServerGroup?,
                  smartProtocolConfig: SmartProtocolConfig) -> Self {
        var serverOffering = serverOffering
        if self.countryIndex != countryIndex {
            serverOffering = nil
        }

        return ModelState(profileName: self.profileName,
                          serverType: self.serverType,
                          countryIndex: countryIndex,
                          serverOffering: self.serverOffering,
                          connectionProtocol: self.connectionProtocol)
            .updating(serverOffering: serverOffering,
                      selectedCountryGroup: selectedCountryGroup,
                      smartProtocolConfig: smartProtocolConfig)
    }

    func updating(serverOffering: ServerOffering?,
                  selectedCountryGroup: ServerGroup?,
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
                          countryIndex: self.countryIndex,
                          serverOffering: serverOffering,
                          connectionProtocol: self.connectionProtocol)
            .updating(connectionProtocol: connectionProtocol)
    }

    func updating(connectionProtocol: ConnectionProtocol?) -> Self {
        Self(profileName: self.profileName,
             serverType: self.serverType,
             countryIndex: self.countryIndex,
             serverOffering: self.serverOffering,
             connectionProtocol: connectionProtocol)
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
