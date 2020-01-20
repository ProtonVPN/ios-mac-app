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
import vpncore

internal enum ModelState {
    
    case standard
    case secureCore
}

class CreateOrEditProfileViewModel: NSObject {
    
    public var saveButtonEnabled = false {
        didSet {
            saveButtonUpdated?()
        }
    }
    public var saveButtonUpdated: (() -> Void)?
    
    private let profileService: ProfileService
    private let serverManager: ServerManager
    private let profileManager: ProfileManager
    private let propertiesManager: PropertiesManager
    private let alertService: AlertService
    private let editedProfile: Profile?
    private let vpnKeychain: VpnKeychainProtocol
    
    let colorPickerViewModel = ColorPickerViewModel()
    
    private var state: ModelState = .standard {
        didSet {
            saveButtonEnabled = true
        }
    }
    
    internal var userTier: Int = 0
    
    var editingExistingProfile: Bool {
        return editedProfile != nil
    }
    
    init(for profile: Profile?, profileService: ProfileService, alertService: AlertService, vpnKeychain: VpnKeychainProtocol, serverManager: ServerManager) {
        self.editedProfile = profile
        self.profileService = profileService
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.serverManager = serverManager
        
        self.profileManager = ProfileManager.shared
        self.propertiesManager = PropertiesManager()
        
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
    
    func makeCountrySelectionViewController() -> SelectionViewController? {
        if let viewController = profileService.makeSelectionViewController() {
            return viewController
        }
        return nil
    }
    
    func makeServerSelectionViewController() -> SelectionViewController? {
        return profileService.makeSelectionViewController()
    }
    
    // MARK: UI Properties
    var backgroundColor: UIColor {
        return UIColor.protonDarkGrey()
    }
    
    var sectionHeaderSize: CGFloat {
        return 38
    }
    
    var cellHeight: CGFloat {
        return 52.5
    }
    
    var numberOfRows: Int {
        return 6
    }
    
    var isSecureCore: Bool {
        return state == .secureCore
    }
    
    var isDefaultProfile = false
    
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
    
    // MARK: Current selection properties
    var selectProfileColorLabel: String {
        return LocalizedString.selectProfileColor.uppercased()
    }
    
    var color: UIColor?
    var name: String = ""
    
    var selectedCountryGroup: CountryGroup? {
        didSet {
            selectedServerOffering = nil
            saveButtonEnabled = true
        }
    }
    var selectedServerOffering: ServerOffering? {
        didSet {
            saveButtonEnabled = true
        }
    }
    
    private func prefillInfo(for profile: Profile) {
        guard profile.profileType == .user, case ProfileIcon.circle(let color) = profile.profileIcon else {
            return
        }
        
        self.color = UIColor(rgbHex: color)
        self.name = profile.name
        self.state = profile.serverType == .secureCore ? .secureCore : .standard
        
        selectedCountryGroup = countries.filter { $0.0.countryCode == profile.serverOffering.countryCode }.first
        selectedServerOffering = profile.serverOffering
    }
    
    func cancelCreation() {
        state = .standard
    }
    
    func toggleState(completion: @escaping (Bool) -> Void) {
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
    
    func toggleDefault() {
        isDefaultProfile = !isDefaultProfile
        saveButtonEnabled = true
    }
    
    func saveProfile(name: String, color: UIColor, usesSecureCore: Bool, serverOffering: ServerOffering) -> ProfileManagerOperationOutcome {
        let type = usesSecureCore ? ServerType.secureCore : ServerType.standard
        let grouping = serverManager.grouping(for: type)
        let serverType: ServerType = usesSecureCore ? .secureCore : .standard
        
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
                              serverType: serverType, serverOffering: serverOffering, name: name)
        
        let result = editedProfile != nil ? profileManager.updateProfile(profile) : profileManager.createProfile(profile)
        
        if result == .success {
            state = .standard
            if isDefaultProfile {
                propertiesManager.quickConnect = profile.id
            } else if let quickConnectId = propertiesManager.quickConnect, quickConnectId == profile.id { // default was on and has now been turned off for this profile
                propertiesManager.quickConnect = nil
            }
        }
        
        return result
    }
    
    func secureCore(enabled: Bool) {
        state = enabled ? .secureCore : .standard
    }
    
    private var countries: [CountryGroup] {
        switch state {
        case .standard:
            return serverManager.grouping(for: .standard)
        case .secureCore:
            return serverManager.grouping(for: .secureCore)
        }
    }
    
    var countryCount: Int {
        return countries.count
    }

    func serverCount(for countryIndex: Int?) -> Int {
        guard let index = countryIndex else {
            return 0
        }
        return countries[index].1.count + 2 // +2 for fastest and random
    }
    
    func serverName(forServerOffering serverOffering: ServerOffering) -> NSAttributedString {
        switch serverOffering {
        case .fastest:
            return defaultServerDescriptor(forIndex: 0)
        case .random:
            return defaultServerDescriptor(forIndex: 1)
        case .custom(let serverWrapper):
            return serverDescriptor(for: serverWrapper.server)
        }
    }
        
}

extension CreateOrEditProfileViewModel {
    
    public var countrySelectionDataSet: SelectionDataSet {
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
            barTitle: LocalizedString.countries,
            backgroundColor: backgroundColor,
            cellHeight: self.cellHeight,
            data: sections,
            selectedIndex: selectedIndex
        )
    }
    
    public var serverSelectionDataSet: SelectionDataSet? {
        // Get newest data, because servers list may have been updated since selectecd group was set
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
            return SelectionSection(title: CoreAppConstants.planTranslatedName(forTier: serverGroup.tier),
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
            barTitle: LocalizedString.server,
            backgroundColor: backgroundColor,
            cellHeight: self.cellHeight,
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
        return newString.length <= UIConstants.maxProfileNameLength
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        return true
    }
}
