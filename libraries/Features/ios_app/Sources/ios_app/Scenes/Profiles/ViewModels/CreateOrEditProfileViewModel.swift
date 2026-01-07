//
//  CreateOrEditProfileViewModel.swift
//  ProtonVPN - Created on 01.07.19.
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

import CommonNetworking
import Dependencies
import Domain
import GSMessages
import LegacyCommon
import Localization
import Persistence
import ProtonCoreFeatureFlags
import Strings
import UIKit
import VPNAppCore
import VPNShared

class CreateOrEditProfileViewModel: NSObject {
    public typealias Factory =
        AppStateManagerFactory & CoreAlertServiceFactory &
        VpnGatewayFactory

    private let factory: Factory
    private lazy var alertService = factory.makeCoreAlertService()
    private lazy var vpnGateway = factory.makeVpnGateway()
    private lazy var appStateManager = factory.makeAppStateManager()

    private let username: String?
    private let profileService: ProfileService
    private let protocolService: ProtocolService
    private let profileManager: ProfileManager
    @Dependency(\.propertiesManager) private var propertiesManager
    private let editedProfile: Profile?
    @Dependency(\.serverRepository) private var serverRepository

    private var state: ServerType = .standard {
        didSet {
            saveButtonEnabled = true
        }
    }

    // We show either standard servers or secure core servers, not both at the same time
    private var secureCoreServerFilter: VPNServerFilter.ServerFeatureFilter {
        state == .standard
            ? .standard
            : .secureCore
    }

    private var colorPickerViewModel: ColorPickerViewModel
    private var color: UIColor {
        colorPickerViewModel.selectedColor
    }

    private var name: String = ""
    private var selectedProtocol: ConnectionProtocol
    private var isDefaultProfile = false

    var userTier: Int = 0 // used by class extension

    var saveButtonEnabled = false {
        didSet {
            saveButtonUpdated?()
        }
    }

    var saveButtonUpdated: (() -> Void)?
    var contentChanged: (() -> Void)?
    var messageHandler: ((String, GSMessageType, [GSMessageOption]) -> Void)?
    var pushHandler: ((UIViewController) -> Void)?

    var editingExistingProfile: Bool {
        editedProfile != nil
    }

    init(
        factory: Factory,
        username: String?,
        for profile: Profile?,
        profileService: ProfileService,
        protocolSelectionService: ProtocolService,
        profileManager: ProfileManager
    ) {
        @Dependency(\.propertiesManager) var propertiesManager
        self.factory = factory
        self.username = username
        self.editedProfile = profile
        self.profileService = profileService
        self.protocolService = protocolSelectionService
        self.profileManager = profileManager
        self.selectedProtocol = propertiesManager.connectionProtocol

        if case let .circle(color) = profile?.profileIcon {
            self.colorPickerViewModel = ColorPickerViewModel(with: UIColor(rgbHex: color))
        } else {
            self.colorPickerViewModel = ColorPickerViewModel()
        }

        if let profile,
           let username,
           let quickConnectProfileId = propertiesManager.getQuickConnect(for: username),
           let quickConnectProfile = profileManager.profile(withId: quickConnectProfileId) {
            self.isDefaultProfile = profile == quickConnectProfile
        }

        @Dependency(\.vpnKeychain) var vpnKeychain
        if let vpnCredentials = try? vpnKeychain.fetchCached() {
            self.userTier = vpnCredentials.maxTier
        }

        super.init()

        if let profile = editedProfile {
            prefillInfo(for: profile)
            self.saveButtonEnabled = false
        }
    }

    var tableViewData: [TableViewSection] {
        var cells = [TableViewCellModel]()
        cells.append(colorCell)
        cells.append(nameCell)
        cells.append(secureCoreCell)
        cells.append(countryCell)
        cells.append(serverCell)
        cells.append(protocolCell)
        return [TableViewSection(title: Localizable.selectProfileColor, cells: cells)]
    }

    func saveProfile(completion: @escaping (Bool) -> Void) {
        guard !name.isEmpty else {
            messageHandler?(Localizable.profileNameIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }

        guard selectedCountryGroup != nil else {
            messageHandler?(Localizable.countrySelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }

        // If not connected to current profile, just save it
        guard !appStateManager.state.isSafeToEnd, let editedProfile, propertiesManager.lastConnectionRequest?.profileId == editedProfile.id else {
            finishSaveProfile(completion: completion)
            return
        }

        // Here you can ask user if he wants to continue/reconnect/etc.

        finishSaveProfile(completion: completion)
    }

    private func finishSaveProfile(completion: @escaping (Bool) -> Void) {
        guard let serverOffering = selectedServerOffering else {
            messageHandler?(Localizable.serverSelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }

        let grouping = serverGroups

        let accessTier: Int = switch serverOffering {
        case let .fastest(countryCode):
            grouping.first(where: { $0.serverOfferingID == countryCode })?.minTier ?? 1

        case let .random(countryCode):
            grouping.first(where: { $0.serverOfferingID == countryCode })?.minTier ?? 1

        case let .custom(serverWrapper):
            serverWrapper.server.tier
        }

        let profileId: String = editedProfile?.id ?? .randomString(length: Profile.idLength)
        let profile = Profile(
            id: profileId,
            accessTier: accessTier,
            profileIcon: .circle(color.hexRepresentation),
            profileType: .user,
            serverType: state,
            serverOffering: serverOffering,
            name: name,
            connectionProtocol: selectedProtocol
        )

        let result = editedProfile != nil ? profileManager.updateProfile(profile) : profileManager.createProfile(profile)

        guard result == .success else {
            messageHandler?(Localizable.profileNameNeedsToBeUnique, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }

        guard let username else {
            messageHandler?(Localizable.vpnstatusNotLoggedin, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }

        state = .standard
        if isDefaultProfile {
            propertiesManager.setQuickConnect(for: username, quickConnect: profile.id)
        } else if let quickConnectId = propertiesManager.getQuickConnect(for: username), quickConnectId == profile.id { // default was on and has now been turned off for this profile
            propertiesManager.setQuickConnect(for: username, quickConnect: nil)
        }

        completion(true)
    }

    private var colorCell: TableViewCellModel {
        colorPickerViewModel = ColorPickerViewModel(with: color)
        colorPickerViewModel.colorChanged = { [weak self] in
            self?.saveButtonEnabled = true
        }

        return TableViewCellModel.colorPicker(viewModel: colorPickerViewModel)
    }

    private var nameCell: TableViewCellModel {
        TableViewCellModel.titleTextField(title: Localizable.name, textFieldText: name, textFieldPlaceholder: Localizable.enterProfileName, textFieldDelegate: self)
    }

    private var secureCoreCell: TableViewCellModel {
        TableViewCellModel.upsellableToggle(
            title: Localizable.featureSecureCore,
            state: { [unowned self] in .available(enabled: state == .secureCore, interactive: true) },
            upsell: { [weak self] in self?.alertService.push(alert: SecureCoreUpsellAlert()) },
            handler: { [weak self] _, callback in
                self?.toggleState(completion: { [weak self] on in
                    callback(on)
                    self?.contentChanged?()
                })
            }
        )
    }

    private var countryCell: TableViewCellModel {
        let completionHandler: (() -> Void) = { [weak self] in
            self?.pushCountrySelectionViewController()
        }

        if let selectedCountry = selectedCountryGroup {
            let countryAttibutedString = countryDescriptor(for: selectedCountry)
            return TableViewCellModel.pushKeyValueAttributed(key: Localizable.country, value: countryAttibutedString, handler: completionHandler)
        } else {
            return TableViewCellModel.pushKeyValue(key: Localizable.country, value: Localizable.selectCountry, handler: completionHandler)
        }
    }

    private var serverCell: TableViewCellModel {
        let completionHandler: (() -> Void) = { [weak self] in
            self?.pushServerSelectionViewController()
        }

        if let selectedServer = selectedServerOffering {
            let serverAttibutedString = serverName(forServerOffering: selectedServer)
            return TableViewCellModel.pushKeyValueAttributed(key: Localizable.server, value: serverAttibutedString, handler: completionHandler)
        } else {
            return TableViewCellModel.pushKeyValue(key: Localizable.server, value: Localizable.selectServer, handler: completionHandler)
        }
    }

    private var protocolCell: TableViewCellModel {
        TableViewCellModel.pushKeyValue(key: Localizable.protocol, value: selectedProtocol.localizedDescription) { [weak self] in
            self?.pushProtocolViewController()
        }
    }

    private var selectedCountryGroup: ServerGroupInfo? {
        didSet {
            selectedServerOffering = nil
            saveButtonEnabled = true

            guard let row = serverGroups.firstIndex(where: { $0 == selectedCountryGroup }) else {
                return
            }
            countryGroup = serverGroups[row]
        }
    }

    private var selectedServerOffering: ServerOffering? {
        didSet {
            saveButtonEnabled = true
        }
    }

    private func prefillInfo(for profile: Profile) {
        guard profile.profileType == .user, case let ProfileIcon.circle(color) = profile.profileIcon else {
            return
        }

        colorPickerViewModel = ColorPickerViewModel(with: UIColor(rgbHex: color))
        name = profile.name
        state = profile.serverType == .secureCore ? .secureCore : .standard

        selectedCountryGroup = serverGroups.first(where: {
            switch $0.kind {
            case let .country(countryCode):
                return countryCode == profile.serverOffering.countryCode
            case let .gateway(name):
                return name == profile.serverOffering.countryCode
            case .city, .state:
                log.assertionFailure("Unsupported server grouping type")
                return false
            }
        })
        selectedServerOffering = profile.serverOffering

        selectedProtocol = profile.connectionProtocol
    }

    private func toggleState(completion: @escaping (Bool) -> Void) {
        if case .standard = state {
            guard userTier.isPaidTier else {
                alertService.push(alert: SecureCoreUpsellAlert())
                return
            }

            state = .secureCore
        } else {
            state = .standard
        }

        // reset country and server selections
        selectedCountryGroup = nil
        selectedServerOffering = nil

        completion(state == .secureCore)
    }

    private func toggleDefault() {
        isDefaultProfile = !isDefaultProfile
        saveButtonEnabled = true
    }

    private var serverGroups: [ServerGroupInfo] {
        serverRepository.getGroups(filteredBy: [.features(secureCoreServerFilter)], groupedBy: .serverType)
    }

    var countryGroup: ServerGroupInfo?

    private func selectedServerOfferingSupports(connectionProtocol: ConnectionProtocol) -> Bool {
        guard let selectedServerOffering else {
            return true
        }

        return selectedServerOffering.supports(
            connectionProtocol: connectionProtocol,
            withCountryGroup: countryGroup,
            smartProtocolConfig: propertiesManager.smartProtocolConfig
        )
    }

    private func serverName(forServerOffering serverOffering: ServerOffering) -> NSAttributedString {
        switch serverOffering {
        case .fastest:
            defaultServerDescriptor(forIndex: 0)
        case .random:
            defaultServerDescriptor(forIndex: 1)
        case let .custom(serverWrapper):
            serverDescriptor(for: serverWrapper.server)
        }
    }

    private func pushCountrySelectionViewController() {
        let selectionViewController = profileService.makeSelectionViewController(dataSet: countrySelectionDataSet) { [weak self] selectedObject in
            guard let selectedCountryGroup = selectedObject as? ServerGroupInfo else {
                return
            }

            self?.selectedCountryGroup = selectedCountryGroup
        }
        pushHandler?(selectionViewController)
    }

    func pushServerSelectionViewController() {
        guard let dataSet = serverSelectionDataSet else {
            messageHandler?(Localizable.countrySelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            return
        }

        let selectionViewController = profileService.makeSelectionViewController(dataSet: dataSet) { [weak self] selectedObject in
            guard let `self` else {
                return
            }

            // Now that we don't load whole objects from the repository, it became
            // not effective to pre-fill ServerOffering objects before one is selected,
            // so we do it here, only for the selected object.
            if let serverInfo = selectedObject as? ServerInfo,
               let vpnServer = serverRepository.getFirstServer(
                   filteredBy: [.logicalID(serverInfo.logical.id)],
                   orderedBy: .fastest
               ) {
                let serverModel = ServerModel(server: vpnServer)
                selectedServerOffering = ServerOffering.custom(ServerWrapper(server: serverModel))
            }

            // Default profiles are given as prepared ServerOffering objects
            if let selectedServerOffering = selectedObject as? ServerOffering {
                self.selectedServerOffering = selectedServerOffering
            }

            resetProtocolIfNotSupportedBySelectedServerOffering()
        }

        pushHandler?(selectionViewController)
    }

    private func resetProtocolIfNotSupportedBySelectedServerOffering() {
        guard !selectedServerOfferingSupports(connectionProtocol: selectedProtocol) else {
            return
        }

        let preferredProtocol = propertiesManager.connectionProtocol
        if selectedProtocol != preferredProtocol,
           selectedServerOfferingSupports(connectionProtocol: preferredProtocol) {
            selectedProtocol = preferredProtocol
        } else if let firstSupportedProtocol = ConnectionProtocol.allCases.first(where: {
            self.selectedServerOfferingSupports(connectionProtocol: $0)
        }) {
            selectedProtocol = firstSupportedProtocol
        } else {
            log.assertionFailure("A server exists that doesn't support any connection protocols.")
            selectedProtocol = .smartProtocol
        }
    }

    private func pushProtocolViewController() {
        let supportedProtocols = ConnectionProtocol.allCases
            .filter { !$0.isDeprecated && selectedServerOfferingSupports(connectionProtocol: $0) }

        let vpnProtocolViewModel = VpnProtocolViewModel(
            connectionProtocol: selectedProtocol,
            smartProtocolConfig: propertiesManager.smartProtocolConfig,
            supportedProtocols: supportedProtocols,
            featureFlags: propertiesManager.featureFlags
        )

        vpnProtocolViewModel.protocolChanged = { [self] connectionProtocol, _ in
            selectedProtocol = connectionProtocol
            saveButtonEnabled = true
        }
        pushHandler?(protocolService.makeVpnProtocolViewController(viewModel: vpnProtocolViewModel))
    }
}

extension CreateOrEditProfileViewModel {
    private var countrySelectionDataSet: SelectionDataSet {
        let rows: [SelectionRow] = serverGroups.map { countryGroup in
            SelectionRow(title: countryDescriptor(for: countryGroup), object: countryGroup)
        }

        let sections: [SelectionSection] = if rows.contains(where: { ($0.object as! ServerGroupInfo).minTier > userTier }) {
            [
                SelectionSection(
                    title: Localizable.countriesFree.uppercased(),
                    cells: rows.filter { ($0.object as! ServerGroupInfo).minTier <= userTier }
                ),
                SelectionSection(
                    title: Localizable.countriesPremium.uppercased(),
                    cells: rows.filter { ($0.object as! ServerGroupInfo).minTier > userTier }
                ),
            ]
        } else {
            [SelectionSection(
                title: nil,
                cells: rows
            )]
        }

        var selectedIndex: IndexPath?
        if let countryGroup = selectedCountryGroup {
            var sectionIndex = 0
            outer: for section in sections {
                var rowIndex = 0
                for row in section.cells {
                    if let object = row.object as? ServerGroupInfo, object == countryGroup {
                        selectedIndex = IndexPath(row: rowIndex, section: sectionIndex)
                        break outer
                    }
                    rowIndex += 1
                }
                sectionIndex += 1
            }
        }

        return SelectionDataSet(
            dataTitle: Localizable.countries,
            data: sections,
            selectedIndex: selectedIndex
        )
    }

    private func currentGroupServersOf(tier: Int) -> [ServerInfo]? {
        guard let countryGroup = selectedCountryGroup else {
            return nil
        }
        let selected = [selectedProtocol.vpnProtocol].compactMap { $0 }
        let supportedProtocols = selected.isEmpty
            ? propertiesManager.smartProtocolConfig.supportedProtocols
            : selected

        return serverRepository.getServers(
            filteredBy: [
                .features(secureCoreServerFilter), // Secure core or not
                .supports(protocol: ProtocolSupport(vpnProtocols: supportedProtocols)), // Only the ones supporting selected protocol
                .kind(countryGroup.kind.serverTypeFilter), // Only from selected country/gateway
                .tier(.exact(tier: tier)),
            ],
            orderedBy: .nameAscending
        )
    }

    private func orderedTiers() -> [Int] {
        [Int.freeTier, Int.paidTier, Int.internalTier].sorted(by: { tier1, tier2 -> Bool in
            if userTier >= tier1 && userTier >= tier2 ||
                userTier < tier1 && userTier < tier2 { // sort within available then non-available groups
                return tier1 > tier2
            } else {
                return tier1 < tier2
            }
        })
    }

    private var serverSelectionDataSet: SelectionDataSet? {
        guard let countryGroup else { return nil }

        var sections: [SelectionSection] = []

        // Default profiles: fastest and random, only if not a gateway!
        if !countryGroup.kind.isGateway {
            sections.append(contentsOf: [
                SelectionSection(title: nil, cells: [
                    SelectionRow(title: defaultServerDescriptor(forIndex: 0), object: ServerOffering.fastest(countryGroup.serverOfferingID)),
                    SelectionRow(title: defaultServerDescriptor(forIndex: 1), object: ServerOffering.random(countryGroup.serverOfferingID)),
                ]),
            ])
        }

        // Servers grouped into sections by tiers
        for tier in orderedTiers() {
            guard let servers = currentGroupServersOf(tier: tier),
                  !servers.isEmpty else {
                continue
            }
            sections.append(SelectionSection(
                title: DomainConstants.serverTierName(forTier: tier),
                cells: servers.map { server in
                    SelectionRow(
                        title: serverDescriptor(for: server),
                        object: server
                    )
                }
            )
            )
        }

        // Detect selected row
        var selectedIndex: IndexPath?
        if let selectedOffering = selectedServerOffering {
            var sectionIndex = 0
            outer: for section in sections {
                var rowIndex = 0
                for row in section.cells {
                    // Object can be either `ServerInfo` or `ServerOffering`
                    if let object = row.object as? ServerOffering, object == selectedOffering {
                        selectedIndex = IndexPath(row: rowIndex, section: sectionIndex)
                        break outer
                    }
                    if let object = row.object as? ServerInfo,
                       case let .custom(serverWrapper) = selectedOffering,
                       object.logical.id == serverWrapper.server.id {
                        selectedIndex = IndexPath(row: rowIndex, section: sectionIndex)
                        break outer
                    }
                    rowIndex += 1
                }
                sectionIndex += 1
            }
        }

        return SelectionDataSet(
            dataTitle: Localizable.server,
            data: sections,
            selectedIndex: selectedIndex
        )
    }
}

extension CreateOrEditProfileViewModel: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentString: NSString = textField.text! as NSString
        let newString: NSString =
            currentString.replacingCharacters(in: range, with: string) as NSString

        saveButtonEnabled = true
        name = newString as String

        return newString.length <= UIConstants.maxProfileNameLength
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }
}
