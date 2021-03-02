//
//  CountryItemViewModel.swift
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

enum CellState: Int {
    case normal
    case expanded
    
    var opposite: CellState {
        switch self {
        case .normal:
            return .expanded
        case .expanded:
            return .normal
        }
    }
}

class CountryItemViewModel {
    
    fileprivate let countryModel: CountryModel
    fileprivate let vpnGateway: VpnGatewayProtocol
    fileprivate let appStateManager: AppStateManager
    private let countriesSectionViewModel: CountriesSectionViewModel
    
    let enabled: Bool
    var cellStateChanged: ((CellState) -> Void)?
    var connectionChanged: ((Bool) -> Void)?
    
    fileprivate(set) var isConnected: Bool
    var state: CellState
    
    var countryCode: String {
        return countryModel.countryCode
    }
    
    var feature: ServerFeature {
        return countryModel.feature
    }
    
    var description: NSAttributedString {
        return formDescription()
    }
    
    var keywordImage: NSImage? {
        if countryModel.feature.contains(.tor) {
            return #imageLiteral(resourceName: "protonvpn-server-tor-list")
        } else if countryModel.feature.contains(.p2p) {
            return #imageLiteral(resourceName: "protonvpn-server-p2p-list")
        } else {
            return nil
        }
    }
    
    var keywordTooltip: String? {
        if countryModel.feature.contains(.tor) {
            return LocalizedString.torDescription
        } else if countryModel.feature.contains(.p2p) {
            return LocalizedString.p2pDescription
        } else {
            return nil
        }
    }
    
    var backgroundColor: NSColor {
        if isConnected {
            return NSColor.protonSelectedGrey()
        } else {
            return NSColor.protonGrey()
        }
    }

    var underMaintenance: Bool {
        return countriesSectionViewModel.isCountryUnderMaintenance(countryModel.countryCode)
    }
    
    init(countryModel: CountryModel, vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager,
         countriesSectionViewModel: CountriesSectionViewModel, enabled: Bool, state: CellState) {
        self.countryModel = countryModel
        self.vpnGateway = vpnGateway
        self.countriesSectionViewModel = countriesSectionViewModel
        self.enabled = enabled
        self.state = state
        self.appStateManager = appStateManager
        isConnected = enabled && vpnGateway.connection == .connected
            && appStateManager.activeConnection()?.server.isSecureCore == false
            && appStateManager.activeConnection()?.server.countryCode == countryModel.countryCode
        
        if enabled {
            startObserving()
        }
    }
    
    func connectAction() {
        isConnected ? vpnGateway.disconnect() : vpnGateway.connectTo(country: countryCode, ofType: .standard)
    }
    
    func changeCellState() {
        state = state.opposite
        countriesSectionViewModel.toggleCell(forCountryCode: countryCode)
        cellStateChanged?(state)
    }
    
    // MARK: - Private functions
    fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    fileprivate func formDescription() -> NSAttributedString {
        let country = LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable
        return country.attributed(withColor: underMaintenance ? NSColor.protonGreyOutOfFocus() : NSColor.protonWhite(), fontSize: 16, alignment: .left)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = connectionChanged {
            if vpnGateway.connection == .connected, let activeServer = appStateManager.activeConnection()?.server,
                activeServer.countryCode == countryCode {
                isConnected = true
            } else {
                isConnected = false
            }
            connectionChanged(isConnected)
        }
    }
}

// MARK: - SecureCoreCountryItemViewModel subclass
class SecureCoreCountryItemViewModel: CountryItemViewModel {
    
    override init(countryModel: CountryModel, vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager,
                  countriesSectionViewModel: CountriesSectionViewModel, enabled: Bool, state: CellState) {
        super.init(countryModel: countryModel, vpnGateway: vpnGateway, appStateManager: appStateManager,
                   countriesSectionViewModel: countriesSectionViewModel, enabled: enabled, state: state)
        
        isConnected = enabled && vpnGateway.connection == .connected
            && appStateManager.activeConnection()?.server.isSecureCore == true
            && appStateManager.activeConnection()?.server.countryCode == countryModel.countryCode
    }
    
    override fileprivate func formDescription() -> NSAttributedString {
        let arrows = NSAttributedString.imageAttachment(named: "double-arrow-right-green", width: 10, height: 10, colored: underMaintenance ? NSColor.protonGreyOutOfFocus() : nil)!
        let country = LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable
        let attributedCountry = ("  " + country).attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        return NSAttributedString.concatenate(arrows, attributedCountry)
    }
    
    override fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    override func connectAction() {
        isConnected ? vpnGateway.disconnect() : vpnGateway.connectTo(country: countryCode, ofType: .secureCore)
    }
}
