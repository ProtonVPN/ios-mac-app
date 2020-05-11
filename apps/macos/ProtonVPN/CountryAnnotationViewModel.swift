//
//  CountryAnnotationViewModel.swift
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

import Foundation
import CoreLocation
import vpncore

class CountryAnnotationViewModel {
    
    enum ViewState {
        case idle
        case hovered
    }
    
    private let minWidth: CGFloat = 100
    private let fallBackWidth: CGFloat = 160
    fileprivate let titlePadding: CGFloat = 15
    
    // triggered by any state change
    var viewStateChange: (() -> Void)?
    
    fileprivate let appStateManager: AppStateManager
    
    let available: Bool
    let countryCode: String
    let coordinate: CLLocationCoordinate2D
    
    var isConnected: Bool {
        return appStateManager.state.isConnected
            && appStateManager.activeServer?.countryCode == countryCode
    }
    
    var attributedConnect: NSAttributedString {
        return LocalizedString.connect.attributed(withColor: available ? .protonWhite() : .protonGreyOutOfFocus(), fontSize: 14, bold: true)
    }
    
    var attributedDisconnect: NSAttributedString {
        return LocalizedString.disconnect.attributed(withColor: available ? .protonWhite() : .protonGreyOutOfFocus(), fontSize: 14, bold: true)
    }
    
    var attributedCountry: NSAttributedString {
        return (LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable).attributed(withColor: available ? .protonWhite() : .protonGreyOutOfFocus(), fontSize: 14)
    }
    
    var buttonWidth: CGFloat {
        if #available(macOS 10.13, *) {
            let countryWidth = attributedCountry.size().width + titlePadding * 2
            let connectWidth = attributedConnect.size().width + titlePadding * 2
            let disconnectWidth = attributedDisconnect.size().width + titlePadding * 2
            let widths = [minWidth, countryWidth, connectWidth, disconnectWidth]
            return 2 * round((widths.max() ?? fallBackWidth) / 2) // prevents bluring on non-retina
        } else {
            return fallBackWidth
        }
    }
    
    fileprivate(set) var state: ViewState = .idle {
        didSet {
            viewStateChange?()
        }
    }
    
    init(appStateManager: AppStateManager, country: CountryModel, userTier: Int, coordinate: CLLocationCoordinate2D) {
        self.appStateManager = appStateManager
        self.countryCode = country.countryCode
        self.available = country.lowestTier <= userTier
        self.coordinate = MapCoordinateTranslator.mapImageCoordinate(from: coordinate)
    }
    
    init(appStateManager: AppStateManager, countryCode: String, coordinate: CLLocationCoordinate2D) {
        self.appStateManager = appStateManager
        self.countryCode = countryCode
        self.available = true
        self.coordinate = MapCoordinateTranslator.mapImageCoordinate(from: coordinate)
    }
    
    func uiStateUpdate(_ state: ViewState) {
        self.state = state
    }
    
    func appStateChanged() {
        if !appStateManager.state.isStable {
            state = .idle
        }
        viewStateChange?()
    }
}

class ConnectableAnnotationViewModel: CountryAnnotationViewModel {
    
    fileprivate let vpnGateway: VpnGatewayProtocol
    
    init(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol, country: CountryModel, userTier: Int, coordinate: CLLocationCoordinate2D) {
        self.vpnGateway = vpnGateway
        super.init(appStateManager: appStateManager, country: country, userTier: userTier, coordinate: coordinate)
    }
}

class StandardCountryAnnotationViewModel: ConnectableAnnotationViewModel {

    var attributedConnectTitle: NSAttributedString {
        return isConnected ? attributedDisconnect : attributedConnect
    }
    
    override var isConnected: Bool {
        return appStateManager.state.isConnected
            && appStateManager.activeServer?.isSecureCore == false
            && appStateManager.activeServer?.countryCode == countryCode
    }
    
    func countryConnectAction() {
        isConnected ? vpnGateway.disconnect() : vpnGateway.connectTo(country: countryCode, ofType: .standard)
    }
}

struct SCExitCountrySelection {

    let selected: Bool
    let connected: Bool
    let countryCode: String
}

struct SCEntryCountrySelection {
    
    let selected: Bool
    let countryCode: String
    let exitCountryCodes: [String]
}

class SCExitCountryAnnotationViewModel: ConnectableAnnotationViewModel {
    
    let servers: [ServerModel]
    
    // triggered by ui-based views' state changes
    var externalViewStateChange: ((SCExitCountrySelection) -> Void)?
    
    override var isConnected: Bool {
        return appStateManager.state.isConnected
            && appStateManager.activeServer?.hasSecureCore == true
            && appStateManager.activeServer?.countryCode == countryCode
    }
    
    init(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol, country: CountryModel, servers: [ServerModel], userTier: Int, coordinate: CLLocationCoordinate2D) {
        self.servers = servers
        super.init(appStateManager: appStateManager, vpnGateway: vpnGateway, country: country, userTier: userTier, coordinate: coordinate)
    }
    
    func serverConnectAction(forRow row: Int) {
        serverIsConnected(for: row) ? vpnGateway.disconnect() : vpnGateway.connectTo(server: servers[row])
    }
    
    func matches(_ code: String) -> Bool {
        return countryCode == code
    }
    
    func attributedServer(for row: Int) -> NSAttributedString {
        guard servers.count > row else { return NSAttributedString() }
        let doubleArrows = NSAttributedString.imageAttachment(named: available ? "double-arrow-right-white" : "double-arrow-right-grey", width: 8, height: 8)!
        let serverName = (" " + servers[row].name).attributed(withColor: available ? .protonWhite() : .protonGreyOutOfFocus(), fontSize: 14)
        let title = NSMutableAttributedString(attributedString: NSAttributedString.concatenate(doubleArrows, serverName))
        let range = (title.string as NSString).range(of: title.string)
        title.setAlignment(.center, range: range)
        return title
    }
    
    func attributedConnectTitle(for row: Int) -> NSAttributedString {
        return serverIsConnected(for: row) ? attributedDisconnect : attributedConnect
    }
    
    func serverIsConnected(for row: Int) -> Bool {
        guard servers.count > row else { return false }
        return appStateManager.state.isConnected
            && appStateManager.activeServer?.countryCode == servers[row].countryCode
            && appStateManager.activeServer?.entryCountryCode == servers[row].entryCountryCode
    }
    
    override func uiStateUpdate(_ state: CountryAnnotationViewModel.ViewState) {
        super.uiStateUpdate(state)
        let selection = SCExitCountrySelection(selected: state == .hovered, connected: isConnected, countryCode: countryCode)
        externalViewStateChange?(selection)
    }
}

class SCEntryCountryAnnotationViewModel: CountryAnnotationViewModel {
    
    // triggered by ui-based views' state changes
    var externalViewStateChange: ((SCEntryCountrySelection) -> Void)?
    
    let exitCountryCodes: [String]
    let country: String
    
    override var isConnected: Bool {
        return appStateManager.state.isConnected
            && appStateManager.activeServer?.hasSecureCore == true
            && appStateManager.activeServer?.entryCountryCode == countryCode
    }
    
    override var attributedCountry: NSAttributedString {
        return String(format: LocalizedString.secureCoreCountry, (LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable)).attributed(withColor: .protonWhite(), fontSize: 14)
    }
    
    override var buttonWidth: CGFloat {
        if #available(macOS 10.13, *) {
            return 2 * round((attributedCountry.size().width + titlePadding * 2) / 2)
        } else {
            return 240
        }
    }
    
    init(appStateManager: AppStateManager, countryCode: String, exitCountryCodes: [String], coordinate: CLLocationCoordinate2D) {
        self.exitCountryCodes = exitCountryCodes
        self.country = LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable
        super.init(appStateManager: appStateManager, countryCode: countryCode, coordinate: coordinate)
    }
    
    func toggleState() {
        state = (state == .idle) ? .hovered : .idle
        let selection = SCEntryCountrySelection(selected: state == .hovered, countryCode: countryCode, exitCountryCodes: exitCountryCodes)
        externalViewStateChange?(selection)
    }
    
    override func uiStateUpdate(_ state: CountryAnnotationViewModel.ViewState) {
        super.uiStateUpdate(state)
        let selection = SCEntryCountrySelection(selected: state == .hovered, countryCode: countryCode, exitCountryCodes: exitCountryCodes)
        externalViewStateChange?(selection)
    }
    
    // MARK: - SecureCoreAnnotation protocol implementation
    func countrySelected(_ selection: SCExitCountrySelection) {
        if selection.selected {
            if exitCountryCodes.contains(selection.countryCode) {
                state = .hovered
            } else {
                state = .idle
            }
        } else {
            if exitCountryCodes.contains(selection.countryCode) {
                state = .idle
            } else {
                return
            }
        }
    }
    
    func secureCoreSelected(_ selection: SCEntryCountrySelection) {
        if selection.countryCode != countryCode {
            state = .idle
        }
    }
}
