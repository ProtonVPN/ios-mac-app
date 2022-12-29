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

internal struct ModelState {
    var serverType: ServerType
    var countryIndex: Int?
    var serverOffering: ServerOffering?
    var connectionProtocol: ConnectionProtocol?

    let editedProfile: Profile?

    static let `default` = Self(serverType: .standard, countryIndex: nil, serverOffering: nil, editedProfile: nil)
}

internal enum DefaultServerOffering: Int, CaseIterable {
    case fastest = 0
    case random = 1

    static let count = allCases.count
    
    var index: Int {
        rawValue
    }
}

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
    
    var prefillContent: ((PrefillInformation) -> Void)?
    var contentChanged: (() -> Void)?
    var contentWarning: ((String) -> Void)?
    var secureCoreWarning: (() -> Void)?
    
    let sessionFinished = NSNotification.Name("CreateNewProfileViewModelSessionFinished") // two observers

    private let serverManager: ServerManager
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    private lazy var sessionService: SessionService = factory.makeSessionService()

    let colorPickerViewModel = ColorPickerViewModel()

    var sysexPending = false
    private var state: ModelState = .default
    internal var userTier: Int = 0
    
    init(editProfile: Notification.Name, factory: Factory) {
        serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: ServerStorageConcrete())
        self.factory = factory
        
        NotificationCenter.default.addObserver(self, selector: #selector(editProfile(_:)), name: editProfile, object: nil)
        setupUserTier()
    }
    
    @objc private func editProfile(_ notification: Notification) {
        if let profile = notification.object as? Profile {
            prefillInfo(for: profile)
        }
    }
    
    private func setupUserTier() {
        do {
            userTier = try vpnKeychain.fetchCached().maxTier
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
        }
    }
    
    private func prefillInfo(for profile: Profile) {
        guard profile.profileType == .user, case ProfileIcon.circle(let color) = profile.profileIcon else {
            return
        }
        
        let tIndex: Int = ProfileUtility.index(for: profile.serverType)
        let grouping = serverManager.grouping(for: profile.serverType)
        
        let cIndex: Int
        let sIndex: Int
        
        switch profile.serverOffering {
        case .fastest(let cCode):
            cIndex = ServerUtility.countryIndex(in: grouping, countryCode: cCode!) ?? 0
            sIndex = DefaultServerOffering.fastest.index
        case .random(let cCode):
            cIndex = ServerUtility.countryIndex(in: grouping, countryCode: cCode!) ?? 0
            sIndex = DefaultServerOffering.random.index
        case .custom(let sWrapper):
            cIndex = ServerUtility.countryIndex(in: grouping, countryCode: sWrapper.server.countryCode) ?? 0
            sIndex = DefaultServerOffering.count + (ServerUtility.serverIndex(in: grouping, model: sWrapper.server) ?? 0)
        }

        state = ModelState(serverType: profile.serverType,
                           countryIndex: cIndex,
                           serverOffering: profile.serverOffering,
                           editedProfile: profile)

        // Important: we shouldn't use `availableProtocols` here, since we'll be saving the index to disk
        // and it could change depending on the server configuration
        let profileProtocolIndex = ConnectionProtocol.allCases.firstIndex(of: profile.connectionProtocol) ?? 0
        prefillContent?(.init(name: profile.name,
                              color: NSColor(rgbHex: color),
                              typeIndex: tIndex,
                              countryIndex: cIndex,
                              serverIndex: sIndex,
                              vpnProtocolIndex: profileProtocolIndex))
    }
    
    func cancelCreation() {
        state = .default
        NotificationCenter.default.post(name: sessionFinished, object: nil)
    }

    func createProfile(name: String) {
        let grouping = serverManager.grouping(for: state.serverType)
        let countryIndex = state.countryIndex!
        let serverOffering = state.serverOffering!
        let countryModel = ServerUtility.country(in: grouping, index: countryIndex)!

        let id: String
        if let editedProfile = state.editedProfile {
            id = editedProfile.id
        } else {
            id = String.randomString(length: Profile.idLength)
        }

        let accessTier: Int
        switch serverOffering {
        case .fastest, .random:
            accessTier = countryModel.lowestTier
        case .custom(let wrapper):
            accessTier = wrapper.server.tier
        }

        let profileIcon: ProfileIcon = .circle(colorPickerViewModel.selectedColor.hexRepresentation)
        let profile = Profile(id: id,
                              accessTier: accessTier,
                              profileIcon: profileIcon,
                              profileType: .user,
                              serverType: state.serverType,
                              serverOffering: serverOffering,
                              name: name,
                              connectionProtocol: state.connectionProtocol!)

        let result = state.editedProfile != nil ?
            profileManager.updateProfile(profile) :
            profileManager.createProfile(profile)

        switch result {
        case .success:
            state = .default
            NotificationCenter.default.post(name: sessionFinished, object: nil)
        case .nameInUse:
            contentWarning?(LocalizedString.profileNameNeedsToBeUnique)
        }
    }

    var isNetshieldEnabled: Bool {
        return propertiesManager.featureFlags.netShield
    }

    var availableProtocols: [ConnectionProtocol] = []
    var selectedProtocol: ConnectionProtocol? {
        state.connectionProtocol
    }

    func countryCount(for typeIndex: Int) -> Int {
        let type = ProfileUtility.serverType(for: typeIndex)
        return serverManager.grouping(for: type).count
    }

    func serverCount(for typeIndex: Int, and countryIndex: Int) -> Int {
        let type = ProfileUtility.serverType(for: typeIndex)
        return DefaultServerOffering.count + serverManager.grouping(for: type)[countryIndex].1.count
    }

    func type(for index: Int) -> ServerType {
        guard index < ServerType.humanReadableCases.count else { return .tor }
        return ServerType.humanReadableCases[index]
    }

    func typeString(for index: Int) -> NSAttributedString {
        return style(type(for: index).localizedString, font: .themeFont(.heading4), alignment: .left)
    }

    func updateType(for index: Int) {
        state.serverType = type(for: index)
    }

    func protocolIndex(for connectionProtocol: ConnectionProtocol) -> Int? {
        availableProtocols.firstIndex(of: connectionProtocol)
    }

    func protocolString(for connectionProtocol: ConnectionProtocol) -> NSAttributedString {
        self.style(connectionProtocol.description, font: .themeFont(.heading4), alignment: .left)
    }

    func connectionProtocol(for index: Int) -> ConnectionProtocol? {
        guard availableProtocols.indices.contains(index) else {
            return nil
        }
        return availableProtocols[index]
    }

    func updateAvailableProtocols() {
        let selectedProtocol = state.connectionProtocol
        var index: Int?
        if let selectedProtocol {
            index = availableProtocols.firstIndex(of: selectedProtocol)
        }

        availableProtocols = ConnectionProtocol.uiSortedCases
            .filter {
                guard selectedOfferingSupports(connectionProtocol: $0) else {
                    return false
                }

                if !propertiesManager.featureFlags.wireGuardTls {
                    switch $0.vpnProtocol {
                    case .wireGuard(.tls), .wireGuard(.tcp):
                        return false
                    default:
                        break
                    }
                }

                return true
            }

        if let selectedProtocol, let index {
            if let newIndex = availableProtocols.firstIndex(of: selectedProtocol) {
                if index != newIndex {
                    contentChanged?()
                }
            } else {
                // new set of available protocols doesn't support the selected one
                state.connectionProtocol = nil
                contentChanged?()
            }
        }
    }

    func updateProtocol(_ connectionProtocol: ConnectionProtocol?) {
        state.connectionProtocol = connectionProtocol
    }
    
    func country(for typeIndex: Int, index countryIndex: Int) -> NSAttributedString {
        let type = ProfileUtility.serverType(for: typeIndex)
        let country = serverManager.grouping(for: type)[countryIndex].0
        return countryDescriptor(for: country)
    }

    func updateCountry(for typeIndex: Int, index countryIndex: Int?) {
        guard let countryIndex else {
            state.countryIndex = nil
            state.serverOffering = nil
            return
        }

        let type = ProfileUtility.serverType(for: typeIndex)
        let grouping = serverManager.grouping(for: type)
        guard let country = ServerUtility.country(in: grouping, index: countryIndex) else {
            state.countryIndex = nil
            state.serverOffering = nil
            return
        }

        state.countryIndex = countryIndex

        switch state.serverOffering {
        case .fastest:
            state.serverOffering = .fastest(country.countryCode)
        case .random:
            state.serverOffering = .random(country.countryCode)
        case .custom:
            state.serverOffering = nil
        case nil:
            break
        }

        if let connectionProtocol = state.connectionProtocol,
           !selectedOfferingSupports(connectionProtocol: connectionProtocol) {
            state.connectionProtocol = nil
        }
    }

    func serverOffering(for typeIndex: Int, and countryIndex: Int, index serverIndex: Int) -> ServerOffering {
        let type = ProfileUtility.serverType(for: typeIndex)
        let country = serverManager.grouping(for: type)[countryIndex]

        if let defaultOffering = DefaultServerOffering(rawValue: serverIndex) {
            let countryCode = country.0.countryCode
            switch defaultOffering {
            case .fastest:
                return .fastest(countryCode)
            case .random:
                return .random(countryCode)
            }
        }

        let adjustedServerIndex = serverIndex - DefaultServerOffering.count
        let server = country.1[adjustedServerIndex]
        return .custom(.init(server: server))
    }

    func updateServer(for typeIndex: Int, and countryIndex: Int?, index serverIndex: Int?) {
        guard let countryIndex, let serverIndex else {
            state.serverOffering = nil
            return
        }
        state.serverOffering = serverOffering(for: typeIndex, and: countryIndex, index: serverIndex)
        updateAvailableProtocols()
    }

    func serverDescriptor(for typeIndex: Int, and countryIndex: Int, index serverIndex: Int) -> NSAttributedString {
        return serverDescriptor(for: serverOffering(for: typeIndex, and: countryIndex, index: serverIndex))
    }

    func selectedOfferingSupports(connectionProtocol: ConnectionProtocol) -> Bool {
        switch state.serverOffering {
        case .fastest, .random:
            guard let countryIndex = state.countryIndex,
                  let servers = ServerUtility.servers(in: serverManager.grouping(for: state.serverType),
                                                      countryIndex: countryIndex) else {
                return true
            }

            return servers.contains {
                $0.supports(connectionProtocol: connectionProtocol,
                            smartProtocolConfig: propertiesManager.smartProtocolConfig)
            }
        case .custom(let wrapper):
            return wrapper.server.supports(connectionProtocol: connectionProtocol,
                                           smartProtocolConfig: propertiesManager.smartProtocolConfig)
        case nil:
            return true
        }
    }

    func checkNetshieldOption( _ netshieldIndex: Int ) -> Bool {
        guard let netshieldType = NetShieldType(rawValue: netshieldIndex), !netshieldType.isUserTierTooLow(userTier) else {
            let upgradeAlert = NetShieldRequiresUpgradeAlert(continueHandler: { [weak self] in
                Task { [weak self] in
                    guard let url = await self?.sessionService.getPlanSession(mode: .upgrade) else { return }
                    SafariService.openLink(url: url)
                }
            })
            self.alertService.push(alert: upgradeAlert)
            return false
        }
        return true
    }

    func isSysexRequired(for protocolIndex: Int) -> Bool {
        connectionProtocol(for: protocolIndex)?.requiresSystemExtension ?? false
    }

    func refreshSysexPending(for protocolIndex: Int) {
        sysexPending = isSysexRequired(for: protocolIndex)
    }

    func shouldShowSysexProgress(for protocolIndex: Int) -> Bool {
        isSysexRequired(for: protocolIndex) && sysexPending
    }

    func checkSysexInstallation(vpnProtocolIndex: Int, completion: @escaping (SystemExtensionResult) -> Void) {
        let vpnProtocol = connectionProtocol(for: vpnProtocolIndex)
        guard let vpnProtocol = vpnProtocol, vpnProtocol.requiresSystemExtension else {
            return
        }

        sysexManager.installOrUpdateExtensionsIfNeeded(userInitiated: true) { result in
            DispatchQueue.main.async { [weak self] in
                self?.sysexPending = false
                completion(result)
            }
        }
    }

    func createSecureCoreWarningViewController() -> SecureCoreWarningViewController {
        return SecureCoreWarningViewController(sessionService: sessionService)
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

    init?(intValue: Int) {
        guard intValue > 0, intValue < Self.uiSortedCases.count else { return nil }
        self = Self.uiSortedCases[intValue]
    }
}
