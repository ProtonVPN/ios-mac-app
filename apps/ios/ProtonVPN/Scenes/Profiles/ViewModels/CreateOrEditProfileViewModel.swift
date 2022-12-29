//
//  CreateNewProfileViewModel.swift
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

import GSMessages
import UIKit
import vpncore

class CreateOrEditProfileViewModel: NSObject {
    
    private let username: String?
    private let profileService: ProfileService
    private let protocolService: ProtocolService
    private let serverManager: ServerManager
    private let profileManager: ProfileManager
    private let propertiesManager: PropertiesManagerProtocol
    private let alertService: AlertService
    private let editedProfile: Profile?
    private let vpnKeychain: VpnKeychainProtocol
    private let appStateManager: AppStateManager
    private var vpnGateway: VpnGatewayProtocol
    
    private var state: ServerType = .standard {
        didSet {
            saveButtonEnabled = true
        }
    }
    
    private var colorPickerViewModel: ColorPickerViewModel
    private var color: UIColor {
        return colorPickerViewModel.selectedColor
    }
    private var name: String = ""
    private var selectedProtocol: ConnectionProtocol
    private var isDefaultProfile = false
    
    internal var userTier: Int = 0 // used by class extension
    
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
        return editedProfile != nil
    }

    init(username: String?, for profile: Profile?, profileService: ProfileService, protocolSelectionService: ProtocolService, alertService: AlertService, vpnKeychain: VpnKeychainProtocol, serverManager: ServerManager, appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol, profileManager: ProfileManager, propertiesManager: PropertiesManagerProtocol) {
        self.username = username
        self.editedProfile = profile
        self.profileService = profileService
        self.protocolService = protocolSelectionService
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.serverManager = serverManager
        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.profileManager = profileManager
        self.propertiesManager = propertiesManager
        self.selectedProtocol = propertiesManager.connectionProtocol
        
        self.colorPickerViewModel = ColorPickerViewModel()
        
        if let profile = profile,
           let username = username,
           let quickConnectProfileId = propertiesManager.getQuickConnect(for: username),
           let quickConnectProfile = profileManager.profile(withId: quickConnectProfileId) {
            self.isDefaultProfile = profile == quickConnectProfile
        }
        
        if let vpnCredentials = try? vpnKeychain.fetchCached() {
            userTier = vpnCredentials.maxTier
        }
        
        super.init()
        
        if let profile = editedProfile {
            prefillInfo(for: profile)
            saveButtonEnabled = false
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
        cells.append(quickConnectCell)
        cells.append(footerCell)
                
        return [TableViewSection(title: LocalizedString.selectProfileColor, cells: cells)]
    }
    
    func saveProfile(completion: @escaping (Bool) -> Void) {
        guard !name.isEmpty else {
            messageHandler?(LocalizedString.profileNameIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }
        
        guard selectedCountryGroup != nil else {
            messageHandler?(LocalizedString.countrySelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }
        
        // If not connected to current profile, just save it
        guard !self.appStateManager.state.isSafeToEnd, let editedProfile = editedProfile, self.propertiesManager.lastConnectionRequest?.profileId == editedProfile.id else {
            self.finishSaveProfile(completion: completion)
            return
        }
        
        // Here you can ask user if he wants to continue/reconnect/etc.
        
        self.finishSaveProfile(completion: completion)
    }
    
    private func finishSaveProfile(completion: @escaping (Bool) -> Void) {
        
        guard let serverOffering = selectedServerOffering else {
            messageHandler?(LocalizedString.serverSelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }
        
        let grouping = serverManager.grouping(for: state)

        let accessTier: Int
        switch serverOffering {
        case .fastest(let countryCode):
            let countryModel = ServerUtility.country(in: grouping, countryCode: countryCode!)!
            accessTier = countryModel.lowestTier
        case .random(let countryCode):
            let countryModel = ServerUtility.country(in: grouping, countryCode: countryCode!)!
            accessTier = countryModel.lowestTier
        case .custom(let serverWrapper):
            accessTier = serverWrapper.server.tier
        }

        let profileId: String = editedProfile?.id ?? .randomString(length: Profile.idLength)
        let profile = Profile(id: profileId,
                              accessTier: accessTier,
                              profileIcon: .circle(color.hexRepresentation),
                              profileType: .user,
                              serverType: state,
                              serverOffering: serverOffering,
                              name: name,
                              connectionProtocol: selectedProtocol)

        let result = editedProfile != nil ? profileManager.updateProfile(profile) : profileManager.createProfile(profile)
        
        guard result == .success else {
            messageHandler?(LocalizedString.profileNameNeedsToBeUnique, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }

        guard let username = username else {
            messageHandler?(LocalizedString.vpnstatusNotLoggedin, GSMessageType.warning, UIConstants.messageOptions)
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
        return TableViewCellModel.titleTextField(title: LocalizedString.name, textFieldText: name, textFieldPlaceholder: LocalizedString.enterProfileName, textFieldDelegate: self)
    }
    
    private var secureCoreCell: TableViewCellModel {
        TableViewCellModel.toggle(title: LocalizedString.featureSecureCore,
                                  on: { [unowned self] in self.state == .secureCore },
                                  enabled: true,
                                  handler: { [weak self] (_, callback) in
            self?.toggleState(completion: { [weak self] on in
                callback(on)
                self?.contentChanged?()
            })
        })
    }
    
    private var countryCell: TableViewCellModel {
        let completionHandler: (() -> Void) = { [weak self] in
            self?.pushCountrySelectionViewController()
        }
        
        if let selectedCountry = selectedCountryGroup {
            let countryAttibutedString = countryDescriptor(for: selectedCountry.0)
            return TableViewCellModel.pushKeyValueAttributed(key: LocalizedString.country, value: countryAttibutedString, handler: completionHandler)
        } else {
            return TableViewCellModel.pushKeyValue(key: LocalizedString.country, value: LocalizedString.selectCountry, handler: completionHandler)
        }
    }
    
    private var serverCell: TableViewCellModel {
        let completionHandler: (() -> Void) = { [weak self] in
            self?.pushServerSelectionViewController()
        }
        
        if let selectedServer = selectedServerOffering {
            let serverAttibutedString = serverName(forServerOffering: selectedServer)
            return TableViewCellModel.pushKeyValueAttributed(key: LocalizedString.server, value: serverAttibutedString, handler: completionHandler)
        } else {
            return TableViewCellModel.pushKeyValue(key: LocalizedString.server, value: LocalizedString.selectServer, handler: completionHandler)
        }
    }
    
    private var protocolCell: TableViewCellModel {
        return TableViewCellModel.pushKeyValue(key: LocalizedString.protocol, value: selectedProtocol.localizedString) { [weak self] in
            self?.pushProtocolViewController()
        }
    }
    
    private var quickConnectCell: TableViewCellModel {
        return TableViewCellModel.toggle(title: LocalizedString.makeDefaultProfile, on: { [unowned self] in self.isDefaultProfile }, enabled: true, handler: { [weak self] (_, callback) in
            self?.toggleDefault()
            callback(self?.isDefaultProfile == true)
        })
    }
    
    private var footerCell: TableViewCellModel {
        return TableViewCellModel.tooltip(text: LocalizedString.defaultProfileTooltip)
    }
    
    private var selectedCountryGroup: CountryGroup? {
        didSet {
            selectedServerOffering = nil
            saveButtonEnabled = true

            guard let row = countries.firstIndex(where: { $0.0 == selectedCountryGroup?.0 }) else {
                return
            }
            countryGroup = countries[row]
        }
    }

    private var selectedServerOffering: ServerOffering? {
        didSet {
            saveButtonEnabled = true
        }
    }
    
    private func prefillInfo(for profile: Profile) {
        guard profile.profileType == .user, case ProfileIcon.circle(let color) = profile.profileIcon else {
            return
        }
        
        self.colorPickerViewModel = ColorPickerViewModel(with: UIColor(rgbHex: color))
        self.name = profile.name
        self.state = profile.serverType == .secureCore ? .secureCore : .standard
        
        selectedCountryGroup = countries.filter { $0.0.countryCode == profile.serverOffering.countryCode }.first
        selectedServerOffering = profile.serverOffering

        selectedProtocol = profile.connectionProtocol
    }
    
    private func toggleState(completion: @escaping (Bool) -> Void) {
        if case .standard = state {
            guard userTier >= CoreAppConstants.VpnTiers.plus else {
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
    
    private var countries: [CountryGroup] {
        serverManager.grouping(for: state)
    }

    var countryGroup: CountryGroup?

    private var serversByTier: [(tier: Int, servers: [ServerModel])]? {
        // Get newest data, because servers list may have been updated since selected group was set
        guard let countryGroup else { return nil }

        let serversAll = countryGroup.1

        return CoreAppConstants.VpnTiers.allCases.compactMap { tier in
            let servers = serversAll.filter { $0.tier == tier }
            if servers.isEmpty {
                return nil
            }
            return (tier, servers)
        }.sorted(by: { (server1, server2) -> Bool in
            if userTier >= server1.tier && userTier >= server2.tier ||
                userTier < server1.tier && userTier < server2.tier { // sort within available then non-available groups
                return server1.tier > server2.tier
            } else {
                return server1.tier < server2.tier
            }
        })
    }

    private func selectedServerOfferingSupports(connectionProtocol: ConnectionProtocol) -> Bool {
        let servers: [ServerModel]?
        switch selectedServerOffering {
        case .custom(let serverWrapper):
            servers = [serverWrapper.server]
        case .fastest, .random:
            servers = self.countryGroup?.1
        case nil:
            servers = nil
        }

        return servers?.contains {
            $0.supports(connectionProtocol: connectionProtocol,
                        smartProtocolConfig: propertiesManager.smartProtocolConfig)
        } != false
    }
    
    private func serverName(forServerOffering serverOffering: ServerOffering) -> NSAttributedString {
        switch serverOffering {
        case .fastest:
            return defaultServerDescriptor(forIndex: 0)
        case .random:
            return defaultServerDescriptor(forIndex: 1)
        case .custom(let serverWrapper):
            return serverDescriptor(for: serverWrapper.server)
        }
    }
    
    private func pushCountrySelectionViewController() {
        let selectionViewController = profileService.makeSelectionViewController(dataSet: countrySelectionDataSet) { [weak self] selectedObject in
            guard let selectedCountryGroup = selectedObject as? CountryGroup else {
                return
            }
            
            self?.selectedCountryGroup = selectedCountryGroup
        }
        pushHandler?(selectionViewController)
    }
    
    func pushServerSelectionViewController() {
        guard let dataSet = serverSelectionDataSet else {
            messageHandler?(LocalizedString.countrySelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            return
        }
        
        let selectionViewController = profileService.makeSelectionViewController(dataSet: dataSet) { [weak self] selectedObject in
            guard let `self`, let selectedServerOffering = selectedObject as? ServerOffering else {
                return
            }
            
            self.selectedServerOffering = selectedServerOffering
            self.resetProtocolIfNotSupportedBySelectedServerOffering()
        }
        
        pushHandler?(selectionViewController)
    }

    private func resetProtocolIfNotSupportedBySelectedServerOffering() {
        guard !self.selectedServerOfferingSupports(connectionProtocol: self.selectedProtocol) else {
            return
        }

        let preferredProtocol = self.propertiesManager.connectionProtocol
        if self.selectedProtocol != preferredProtocol,
           self.selectedServerOfferingSupports(connectionProtocol: preferredProtocol) {
            self.selectedProtocol = preferredProtocol
        } else if let firstSupportedProtocol = ConnectionProtocol.allCases.first(where: {
            self.selectedServerOfferingSupports(connectionProtocol: $0)
        }) {
            self.selectedProtocol = firstSupportedProtocol
        } else {
            assertionFailure("A server exists that doesn't support any connection protocols.")
            self.selectedProtocol = .smartProtocol
        }
    }
    
    private func pushProtocolViewController() {
        let supportedProtocols = ConnectionProtocol.allCases
            .filter(selectedServerOfferingSupports(connectionProtocol:))

        let vpnProtocolViewModel = VpnProtocolViewModel(connectionProtocol: selectedProtocol,
                                                        smartProtocolConfig: propertiesManager.smartProtocolConfig,
                                                        supportedProtocols: supportedProtocols,
                                                        featureFlags: propertiesManager.featureFlags)

        vpnProtocolViewModel.protocolChanged = { [self] connectionProtocol, _ in
            self.selectedProtocol = connectionProtocol
            self.saveButtonEnabled = true
        }
        pushHandler?(protocolService.makeVpnProtocolViewController(viewModel: vpnProtocolViewModel))
    }
    
}

extension CreateOrEditProfileViewModel {
    
    private var countrySelectionDataSet: SelectionDataSet {
        let rows: [SelectionRow] = countries.map({ countryGroup in
            return SelectionRow(title: countryDescriptor(for: countryGroup.0), object: countryGroup)
        })
                
        let sections: [SelectionSection]
        if rows.contains(where: { ($0.object as! CountryGroup).0.lowestTier > userTier }) {
            sections = [
                SelectionSection(
                    title: LocalizedString.countriesFree.uppercased(),
                    cells: rows.filter { ($0.object as! CountryGroup).0.lowestTier <= userTier }),
                SelectionSection(
                    title: LocalizedString.countriesPremium.uppercased(),
                    cells: rows.filter { ($0.object as! CountryGroup).0.lowestTier > userTier }),
            ]
        } else {
            sections = [SelectionSection(
                title: nil,
                cells: rows)
            ]
        }
        
        var selectedIndex: IndexPath?
        if let countryGroup = selectedCountryGroup {
            var sectionIndex = 0
            outer: for section in sections {
                var rowIndex = 0
                for row in section.cells {
                    if let object = row.object as? CountryGroup, object == countryGroup {
                        selectedIndex = IndexPath(row: rowIndex, section: sectionIndex)
                        break outer
                    }
                    rowIndex += 1
                }
                sectionIndex += 1
            }
        }
        
        return SelectionDataSet(
            dataTitle: LocalizedString.countries,
            data: sections,
            selectedIndex: selectedIndex
        )
    }
    
    private var serverSelectionDataSet: SelectionDataSet? {
        guard let countryGroup, let serversByTier else { return nil }

        var selectedIndex: IndexPath?

        var sections: [SelectionSection] = [
            SelectionSection(title: nil, cells: [
                SelectionRow(title: defaultServerDescriptor(forIndex: 0), object: ServerOffering.fastest(countryGroup.0.countryCode)),
                SelectionRow(title: defaultServerDescriptor(forIndex: 1), object: ServerOffering.random(countryGroup.0.countryCode)),
            ])
        ]

        sections.append(contentsOf: serversByTier.map { serverGroup in
            let rows: [SelectionRow] = serverGroup.servers.map {
                .init(title: serverDescriptor(for: $0),
                      object: ServerOffering.custom(ServerWrapper(server: $0)))
            }

            return SelectionSection(title: CoreAppConstants.serverTierName(forTier: serverGroup.tier),
                                    cells: rows)
        })

        if let selectedOffering = selectedServerOffering {
            var sectionIndex = 0
            outer: for section in sections {
                var rowIndex = 0
                for row in section.cells {
                    if let object = row.object as? ServerOffering, object == selectedOffering {
                        selectedIndex = IndexPath(row: rowIndex, section: sectionIndex)
                        break outer
                    }
                    rowIndex += 1
                }
                sectionIndex += 1
            }
        }
        
        return SelectionDataSet(
            dataTitle: LocalizedString.server,
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
