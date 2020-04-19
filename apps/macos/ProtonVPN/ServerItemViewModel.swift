//
//  ServerItemViewModel.swift
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

class ServerItemViewModel {
    
    fileprivate let vpnGateway: VpnGatewayProtocol
    fileprivate let appStateManager: AppStateManager
    private weak var countriesSectionViewModel: CountriesSectionViewModel! // weak to prevent retain cycle
    
    let serverModel: ServerModel
    
    let requiresUpgrade: Bool
    let underMaintenance: Bool
    
    private(set) var isConnected: Bool = false
    fileprivate(set) var isCountryConnected: Bool = false
    var connectionChanged: ((Bool) -> Void)?
    
    fileprivate var canConnect: Bool {
        return !requiresUpgrade && !underMaintenance
    }
    
    var enabled: Bool {
        return !underMaintenance
    }
    
    var load: Int {
        return serverModel.load
    }
    
    var description: NSAttributedString {
        return serverModel.name.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
    }
    
    var secondaryDescription: NSAttributedString {
        return formSecondaryDescription()
    }
    
    var hasKeyword: Bool {
        return serverModel.feature.rawValue > 1
    }
    
    var keywordIcons: [(NSImage, String)] {
        var icons = [(NSImage, String)]()
        
        if serverModel.tier >= 2 {
            icons.append((#imageLiteral(resourceName: "protonvpn-server-premium-list"), LocalizedString.premiumDescription))
        }
        if serverModel.feature.contains(.tor) {
            icons.append((#imageLiteral(resourceName: "protonvpn-server-tor-list"), LocalizedString.torDescription))
        }
        if serverModel.feature.contains(.p2p) {
            icons.append((#imageLiteral(resourceName: "protonvpn-server-p2p-list"), LocalizedString.p2pDescription))
        }
        
        return icons
    }
    
    var backgroundColor: NSColor {
        if isCountryConnected {
            return NSColor.protonSelectedGrey()
        } else {
            return NSColor.protonGrey()
        }
    }
    
    init(serverModel: ServerModel, vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager,
         countriesSectionViewModel: CountriesSectionViewModel, requiresUpgrade: Bool) {
        self.serverModel = serverModel
        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.countriesSectionViewModel = countriesSectionViewModel
        self.requiresUpgrade = requiresUpgrade
        self.underMaintenance = serverModel.underMaintenance
        isConnected = canConnect && vpnGateway.connection == .connected
            && appStateManager.activeConnection()?.server.id == serverModel.id
        isCountryConnected = vpnGateway.connection == .connected
            && appStateManager.activeConnection()?.server.isSecureCore == false
            && appStateManager.activeConnection()?.server.countryCode == serverModel.countryCode
        
        if canConnect {
            startObserving()
        }
    }
    
    func isParentExpanded() -> Bool {
        return countriesSectionViewModel.isCountryExpanded(serverModel.countryCode)
    }
    
    func connectAction() {
        isConnected ? vpnGateway.disconnect() : vpnGateway.connectTo(server: serverModel)
    }
    
    // MARK: - Private functions
    fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    private func formSecondaryDescription() -> NSAttributedString {
        let description: String
        var bold = true
        if requiresUpgrade {
            description = LocalizedString.upgrade
        } else if underMaintenance {
            description = LocalizedString.maintenance
        } else {
            bold = false
            description = (serverModel.isFree ? "" : (serverModel.city ?? ""))
        }
        
        return description.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, bold: bold, alignment: .right)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = connectionChanged {
            if vpnGateway.connection == .connected, let activeServer = appStateManager.activeConnection()?.server {
                isConnected = activeServer.id == serverModel.id
                isCountryConnected = activeServer.countryCode == serverModel.countryCode
            } else {
                isConnected = false
                isCountryConnected = false
            }
            connectionChanged(isConnected)
        }
    }
}

// MARK: - SecureCoreServerItemViewModel subclass
class SecureCoreServerItemViewModel: ServerItemViewModel {
    
    private var color: NSColor {
        return canConnect ? .protonWhite() : .protonGreyOutOfFocus()
    }
    
    var via: NSAttributedString {
        return "via".attributed(withColor: color, fontSize: 16, alignment: .left)
    }
    
    var countryCode: String {
        return serverModel.isSecureCore ? serverModel.entryCountryCode : ""
    }
    
    override var description: NSAttributedString {
        return formDescription()
    }
    
    var fullDescription: String {
        return String(format: "%@ %@ %@", serverModel.country, description.string, secondaryDescription.string)
    }	
    
    override var secondaryDescription: NSAttributedString {
        return formSecondaryDescription()
    }
    
    override init(serverModel: ServerModel, vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager,
                  countriesSectionViewModel: CountriesSectionViewModel, requiresUpgrade: Bool) {
        super.init(serverModel: serverModel, vpnGateway: vpnGateway, appStateManager: appStateManager,
                   countriesSectionViewModel: countriesSectionViewModel, requiresUpgrade: requiresUpgrade)
        
        isCountryConnected = vpnGateway.connection == .connected
            && appStateManager.activeConnection()?.server.hasSecureCore == true
            && appStateManager.activeConnection()?.server.countryCode == serverModel.countryCode
    }
    
    override fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    private func formDescription() -> NSAttributedString {
        if !serverModel.isSecureCore {
            return LocalizedString.unavailable.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        }
        let country: NSAttributedString
        country = String(format: LocalizedString.viaCountry, serverModel.entryCountry).attributed(withColor: color, fontSize: 16, alignment: .left)
        return country
    }
    
    private func formSecondaryDescription() -> NSAttributedString {
        let description: String
        if underMaintenance {
            description = LocalizedString.maintenance
        } else if requiresUpgrade {
            description = LocalizedString.upgrade
        } else {
            description = ""
        }
        
        return description.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, bold: true, alignment: .right)
    }
}
