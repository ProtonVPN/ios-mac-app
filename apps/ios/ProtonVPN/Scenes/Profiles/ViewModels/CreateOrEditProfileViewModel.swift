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

import UIKit

import GSMessages

import Domain
import Strings
import VPNAppCore
import LegacyCommon

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
        guard !self.appStateManager.state.isSafeToEnd, let editedProfile = editedProfile, self.propertiesManager.lastConnectionRequest?.profileId == editedProfile.id else {
            self.finishSaveProfile(completion: completion)
            return
        }
        
        // Here you can ask user if he wants to continue/reconnect/etc.
        
        self.finishSaveProfile(completion: completion)
    }
    
    private func finishSaveProfile(completion: @escaping (Bool) -> Void) {
        
        guard let serverOffering = selectedServerOffering else {
            messageHandler?(Localizable.serverSelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }
        
        let grouping = serverManager.grouping(for: state)

        let accessTier: Int
        switch serverOffering {
        case .fastest(let countryCode):
            accessTier = grouping.first(where: { $0.serverOfferingId == countryCode })?.kind.lowestTier ?? 1

        case .random(let countryCode):
            accessTier = grouping.first(where: { $0.serverOfferingId == countryCode })?.kind.lowestTier ?? 1

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
            messageHandler?(Localizable.profileNameNeedsToBeUnique, GSMessageType.warning, UIConstants.messageOptions)
            completion(false)
            return
        }

        guard let username = username else {
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
        return TableViewCellModel.titleTextField(title: Localizable.name, textFieldText: name, textFieldPlaceholder: Localizable.enterProfileName, textFieldDelegate: self)
    }
    
    private var secureCoreCell: TableViewCellModel {
        TableViewCellModel.upsellableToggle(
            title: Localizable.featureSecureCore,
            state: { [unowned self] in .available(enabled: self.state == .secureCore, interactive: true) },
            upsell: { [weak self] in self?.alertService.push(alert: SecureCoreUpsellAlert()) },
            handler: { [weak self] (_, callback) in
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
        return TableViewCellModel.pushKeyValue(key: Localizable.protocol, value: selectedProtocol.localizedString) { [weak self] in
            self?.pushProtocolViewController()
        }
    }
    
    private var quickConnectCell: TableViewCellModel {
        return TableViewCellModel.upsellableToggle(
            title: Localizable.makeDefaultProfile,
            state: { [unowned self] in .available(enabled: self.isDefaultProfile, interactive: true) },
            upsell: {
                // No Upsell: free users cannot be shown this UI since only paid users are allowed to create or edit profiles
            },
            handler: { [weak self] (_, callback) in
                self?.toggleDefault()
                callback(self?.isDefaultProfile == true)
            }
        )
    }
    
    private var footerCell: TableViewCellModel {
        return TableViewCellModel.tooltip(text: Localizable.defaultProfileTooltip)
    }
    
    private var selectedCountryGroup: ServerGroup? {
        didSet {
            selectedServerOffering = nil
            saveButtonEnabled = true

            guard let row = countries.firstIndex(where: { $0 == selectedCountryGroup }) else {
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
        
        selectedCountryGroup = countries.first(where: {
            switch $0.kind {
            case .country(let country):
                return country.countryCode == profile.serverOffering.countryCode
            case .gateway(let name):
                return name == profile.serverOffering.countryCode
            }
        })
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
    
    private var countries: [ServerGroup] {
        serverManager.grouping(for: state)
    }

    var countryGroup: ServerGroup?

    private var serversByTier: [(tier: Int, servers: [ServerModel])]? {
        // Get newest data, because servers list may have been updated since selected group was set
        guard let countryGroup else { return nil }

        let serversAll = countryGroup.servers

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
        selectedServerOffering?.supports(connectionProtocol: connectionProtocol,
                                         withCountryGroup: self.countryGroup,
                                         smartProtocolConfig: propertiesManager.smartProtocolConfig) != false
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
            guard let selectedCountryGroup = selectedObject as? ServerGroup else {
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
            log.assertionFailure("A server exists that doesn't support any connection protocols.")
            self.selectedProtocol = .smartProtocol
        }
    }
    
    private func pushProtocolViewController() {
        let supportedProtocols = ConnectionProtocol.allCases
            .filter { !$0.isDeprecated && selectedServerOfferingSupports(connectionProtocol: $0)}

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
            return SelectionRow(title: countryDescriptor(for: countryGroup), object: countryGroup)
        })
                
        let sections: [SelectionSection]
        if rows.contains(where: { ($0.object as! ServerGroup).kind.lowestTier > userTier }) {
            sections = [
                SelectionSection(
                    title: Localizable.countriesFree.uppercased(),
                    cells: rows.filter { ($0.object as! ServerGroup).kind.lowestTier <= userTier }),
                SelectionSection(
                    title: Localizable.countriesPremium.uppercased(),
                    cells: rows.filter { ($0.object as! ServerGroup).kind.lowestTier > userTier }),
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
                    if let object = row.object as? ServerGroup, object == countryGroup {
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
    
    private var serverSelectionDataSet: SelectionDataSet? {
        guard let countryGroup, let serversByTier else { return nil }

        var selectedIndex: IndexPath?

        var sections: [SelectionSection] = [
            SelectionSection(title: nil, cells: [
                SelectionRow(title: defaultServerDescriptor(forIndex: 0), object: ServerOffering.fastest(countryGroup.serverOfferingId)),
                SelectionRow(title: defaultServerDescriptor(forIndex: 1), object: ServerOffering.random(countryGroup.serverOfferingId)),
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
