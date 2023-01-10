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
import vpncore
import VPNShared

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

    private var userTier: Int = CoreAppConstants.VpnTiers.visionary
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

    var selectedServerGrouping: [CountryGroup] {
        serverManager.grouping(for: state.serverType)
    }

    var selectedCountryGroup: CountryGroup? {
        guard let countryIndex = state.countryIndex else {
            return nil
        }
        return ServerUtility.countryGroup(in: selectedServerGrouping, index: countryIndex)
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
        [.init(title: menuStyle(LocalizedString.selectCountry),
               checked: state.countryIndex == nil,
               handler: { [weak self] in self?.update(countryIndex: nil) })] +
        // Countries by index in their grouping
        serverManager.grouping(for: state.serverType).enumerated().map { (index, grouping) in
                .init(title: countryDescriptor(for: grouping.country),
                      checked: state.countryIndex == index,
                      handler: { [weak self] in self?.update(countryIndex: index) })
        }
    }

    /// Contains one placeholder item at the beginning. If a country is selected, the placeholder will
    /// be followed by the `fastest` offering, the `random` offering, and then the list of all servers
    /// for that country.
    var serverMenuItems: [PopUpButtonItemViewModel] {
        let placeholder: PopUpButtonItemViewModel =
            .init(title: menuStyle(LocalizedString.selectServer),
                  checked: state.serverOffering == nil,
                  handler: { [weak self] in self?.update(serverOffering: nil) })

        guard let group = selectedCountryGroup else { return [placeholder] }

        let (countryCode, servers) = (group.0.countryCode, group.1)
        let offerings: [ServerOffering] = [.fastest(countryCode), .random(countryCode)]
            + servers.map { .custom(.init(server: $0)) }

        return [placeholder]
            + offerings.map { offering in
                .init(title: serverDescriptor(for: offering),
                      checked: state.serverOffering == offering,
                      handler: { [weak self] in self?.update(serverOffering: offering) })
            }
    }

    /// If the selected offering does not support a given protocol or a required feature flag is disabled,
    /// the protocol list will not show it. If the selected protocol requires a system extension, and that
    /// extension is not installed or unavailable, it will be switched to one that doesn't require one.
    var protocolMenuItems: [PopUpButtonItemViewModel] {
        ConnectionProtocol.uiSortedCases.compactMap { (item) -> PopUpButtonItemViewModel? in
            if !propertiesManager.featureFlags.wireGuardTls {
                switch item.vpnProtocol {
                case .wireGuard(.tcp), .wireGuard(.tls):
                    return nil
                default:
                    break
                }
            }

            guard state.serverOffering?.supports(connectionProtocol: item,
                                                 withCountryGroup: selectedCountryGroup,
                                                 smartProtocolConfig: propertiesManager.smartProtocolConfig) != false else {
                return nil
            }

            return .init(title: menuStyle(item.localizedString),
                         checked: item == state.connectionProtocol,
                         handler: { [weak self] in self?.update(connectionProtocol: item) })
        }
    }

    // MARK: Helper functions and initialization

    private func menuStyle(_ string: String) -> NSAttributedString {
        style(string, font: .themeFont(.heading4), alignment: .left)
    }

    var userTierSupportsSecureCore: Bool {
        CoreAppConstants.VpnTiers.plus <= userTier
    }

    func userTierSupports(country: CountryModel) -> Bool {
        country.lowestTier <= userTier
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

        sysexManager.installOrUpdateExtensionsIfNeeded(userInitiated: true, shouldStartTour: shouldStartTour) { result in
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
        if let countryCode = profile.serverOffering.countryCode {
            countryIndex = ServerUtility.countryIndex(in: grouping,
                                                      countryCode: countryCode)

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
            errors.append(LocalizedString.profileNameIsRequired)
        }
        if (profileName?.count ?? 0) > 25 {
            errors.append(LocalizedString.profileNameIsTooLong)
        }
        if state.countryIndex == nil {
            errors.append(LocalizedString.countrySelectionIsRequired)
        }
        if state.serverOffering == nil {
            errors.append(LocalizedString.serverSelectionIsRequired)
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
            accessTier = selectedCountryGroup.country.lowestTier
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
            contentWarning?(LocalizedString.profileNameNeedsToBeUnique)
        }
    }
}

extension CreateNewProfileViewModel: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .field, .text, .icon:
            return .normal
        case .border, .background:
            return .weak
        }
    }
}

extension ConnectionProtocol {
    static let uiSortedCases = allCases.sorted(by: uiSort)
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
                  newTypeGrouping: [CountryGroup],
                  selectedCountryGroup: CountryGroup?,
                  smartProtocolConfig: SmartProtocolConfig) -> Self {
        var countryIndex = countryIndex
        if let selectedCountryCode = selectedCountryGroup?.0.countryCode {
            countryIndex = ServerUtility.countryIndex(in: newTypeGrouping, countryCode: selectedCountryCode)
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
                  selectedCountryGroup: CountryGroup?,
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
                  selectedCountryGroup: CountryGroup?,
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
