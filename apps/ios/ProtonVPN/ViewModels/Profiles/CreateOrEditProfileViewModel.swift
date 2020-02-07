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

fileprivate enum ModelState {
    
    case standard
    case secureCore
}

class CreateOrEditProfileViewModel: NSObject {
    
    private let profileService: ProfileService
    private let protocolService: ProtocolService
    private let serverManager: ServerManager
    private let profileManager: ProfileManager
    private let propertiesManager: PropertiesManager
    private let alertService: AlertService
    private let editedProfile: Profile?
    private let vpnKeychain: VpnKeychainProtocol
    
    private var state: ModelState = .standard {
        didSet {
            saveButtonEnabled = true
        }
    }
    
    private var colorPickerViewModel: ColorPickerViewModel
    private var color: UIColor {
        return colorPickerViewModel.selectedColor
    }
    private var name: String = ""
    private var isSecureCore: Bool {
        return state == .secureCore
    }
    private var vpnProtocol: VpnProtocol
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
    
    init(for profile: Profile?, profileService: ProfileService, protocolSelectionService: ProtocolService, alertService: AlertService, vpnKeychain: VpnKeychainProtocol, serverManager: ServerManager) {
        self.editedProfile = profile
        self.profileService = profileService
        self.protocolService = protocolSelectionService
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.serverManager = serverManager
        
        self.profileManager = ProfileManager.shared
        self.propertiesManager = PropertiesManager()
        
        self.vpnProtocol = propertiesManager.vpnProtocol
        
        self.colorPickerViewModel = ColorPickerViewModel()
        
        if let profile = profile, let quickConnectProfileId = propertiesManager.quickConnect, let quickConnectProfile = profileManager.profile(withId: quickConnectProfileId) {
            self.isDefaultProfile = profile == quickConnectProfile
        }
        
        if let vpnCredentials = try? vpnKeychain.fetch() {
            userTier = vpnCredentials.maxTier
        }
        
        super.init()
        
        if let profile = editedProfile {
            prefillInfo(for: profile)
            saveButtonEnabled = false
        }
    }
    
    var tableViewData: [TableViewSection] {
        let sections: [TableViewSection] = [
            TableViewSection(title: LocalizedString.selectProfileColor.uppercased(), cells: [
                colorCell,
                nameCell,
                secureCoreCell,
                countryCell,
                serverCell,
                protocolCell,
                quickConnectCell,
                footerCell
            ])
        ]
        
        return sections
    }
    
    func saveProfile() -> Bool {
        guard !name.isEmpty else {
            messageHandler?(LocalizedString.profileNameIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            return false
        }
        
        guard selectedCountryGroup != nil else {
            messageHandler?(LocalizedString.countrySelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            return false
        }
        
        guard let serverOffering = selectedServerOffering else {
            messageHandler?(LocalizedString.serverSelectionIsRequired, GSMessageType.warning, UIConstants.messageOptions)
            return false
        }
        
        let serverType: ServerType = isSecureCore ? .secureCore : .standard
        let grouping = serverManager.grouping(for: serverType)
        
        let id: String
        if let editedProfile = editedProfile {
            id = editedProfile.id
        } else {
            id = String.randomString(length: Profile.idLength)
        }
        
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
        
        let profile = Profile(id: id, accessTier: accessTier, profileIcon: .circle(color.hexRepresentation), profileType: .user,
                              serverType: serverType, serverOffering: serverOffering, name: name, vpnProtocol: vpnProtocol)
        
        let result = editedProfile != nil ? profileManager.updateProfile(profile) : profileManager.createProfile(profile)
        
        guard result == .success else {
            messageHandler?(LocalizedString.profileNameUnique, GSMessageType.warning, UIConstants.messageOptions)
            return false
        }
        
        state = .standard
        if isDefaultProfile {
            propertiesManager.quickConnect = profile.id
        } else if let quickConnectId = propertiesManager.quickConnect, quickConnectId == profile.id { // default was on and has now been turned off for this profile
            propertiesManager.quickConnect = nil
        }
        
        return true
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
        return TableViewCellModel.toggle(title: LocalizedString.useSecureCore, on: isSecureCore, enabled: true) { [weak self] on in
            self?.toggleState(completion: { [weak self] on in
                self?.contentChanged?()
            })
        }
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
        return TableViewCellModel.pushKeyValue(key: LocalizedString.protocolLabel, value: vpnProtocol.localizedString) { [weak self] in
            self?.pushProtocolViewController()
        }
    }
    
    var footerView: UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIConstants.cellHeight))
        let label = UILabel(frame: CGRect(x: 18, y: 0, width: UIScreen.main.bounds.width - 18 * 2, height: UIConstants.cellHeight))
        label.text = LocalizedString.defaultProfileTooltip
        label.textColor = .protonFontLightGrey()
        label.font = .systemFont(ofSize: 15)
        label.numberOfLines = 0
        
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 10).isActive = true
        label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor).isActive = true
        label.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        return view
    }
    
    private var quickConnectCell: TableViewCellModel {
        return TableViewCellModel.toggle(title: LocalizedString.makeDefaultProfile, on: isDefaultProfile, enabled: true) { [weak self] on in
            self?.toggleDefault()
        }
    }
    
    private var footerCell: TableViewCellModel {
        return TableViewCellModel.tooltip(text: LocalizedString.defaultProfileTooltip)
    }
    
    private var selectedCountryGroup: CountryGroup? {
        didSet {
            selectedServerOffering = nil
            saveButtonEnabled = true
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
        
        self.vpnProtocol = profile.vpnProtocol
    }
    
    private func toggleState(completion: @escaping (Bool) -> Void) {
        if case ModelState.standard = state {
            guard userTier >= CoreAppConstants.VpnTiers.visionary else {
                alertService.push(alert: UpgradeRequiredAlert(tier: CoreAppConstants.VpnTiers.visionary, serverType: .secureCore, forSpecificCountry: false, confirmHandler: { completion(false) }))
                return
            }
            
            state = ModelState.secureCore
        } else {
            state = ModelState.standard
        }
        
        // reset country and server selections
        selectedCountryGroup = nil
        selectedServerOffering = nil
        
        completion(true)
    }
    
    private func toggleDefault() {
        isDefaultProfile = !isDefaultProfile
        saveButtonEnabled = true
    }
    
    private var countries: [CountryGroup] {
        switch state {
        case .standard:
            return serverManager.grouping(for: .standard)
        case .secureCore:
            return serverManager.grouping(for: .secureCore)
        }
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
            guard let selectedServerOffering = selectedObject as? ServerOffering else {
                return
            }
            
            self?.selectedServerOffering = selectedServerOffering
        }
        
        pushHandler?(selectionViewController)
    }
    
    private func pushProtocolViewController() {
        let vpnProtocolViewModel = VpnProtocolViewModel(vpnProtocol: vpnProtocol)
        vpnProtocolViewModel.protocolChanged = { [self] vpnProtocol in
            self.vpnProtocol = vpnProtocol
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
        // Get newest data, because servers list may have been updated since selected group was set
        guard let row = countries.firstIndex(where: { $0.0 == selectedCountryGroup?.0 }) else {
            return nil
        }
        let countryGroup = countries[row]
        
        let serversAll = countryGroup.1
        var serversByTier: [(tier: Int, servers: [ServerModel])] = CoreAppConstants.VpnTiers.allCases.compactMap { tier in
            let servers = serversAll.filter { $0.tier == tier }
            if servers.isEmpty {
                return nil
            }
            return (tier, servers)
        }
        serversByTier.sort(by: { (server1, server2) -> Bool in
            if userTier >= server1.tier && userTier >= server2.tier ||
                userTier < server1.tier && userTier < server2.tier { // sort within available then non-available groups
                return server1.tier > server2.tier
            } else {
                return server1.tier < server2.tier
            }
        })
        
        var selectedIndex: IndexPath?
        
        var sections: [SelectionSection] = [
            SelectionSection(title: nil, cells: [
                SelectionRow(title: defaultServerDescriptor(forIndex: 0), object: ServerOffering.fastest(countryGroup.0.countryCode)),
                SelectionRow(title: defaultServerDescriptor(forIndex: 1), object: ServerOffering.random(countryGroup.0.countryCode)),
            ])
        ]
        
        sections.append(contentsOf: serversByTier.map { serverGroup in
            return SelectionSection(title: CoreAppConstants.serverTierName(forTier: serverGroup.tier),
                                    cells: serverGroup.servers.map { server in
                                        return SelectionRow(title: serverDescriptor(for: server), object: ServerOffering.custom(ServerWrapper(server: server)))
                                    }
            )
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
