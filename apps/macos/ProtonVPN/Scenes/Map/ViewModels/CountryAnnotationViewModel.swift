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
import Cocoa

class CountryAnnotationViewModel: CustomStyleContext {
    
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
            && appStateManager.activeConnection()?.server.countryCode == countryCode
    }
    
    var attributedConnect: NSAttributedString {
        return self.style(LocalizedString.connect, font: .themeFont(bold: true))
    }
    
    var attributedDisconnect: NSAttributedString {
        return self.style(LocalizedString.disconnect, font: .themeFont(bold: true))
    }
    
    var attributedCountry: NSAttributedString {
        let countryName = LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable
        return self.style(countryName, font: .themeFont(bold: true))
    }
    
    var buttonWidth: CGFloat {
        let countryWidth = attributedCountry.size().width + titlePadding * 2
        let connectWidth = attributedConnect.size().width + titlePadding * 2
        let disconnectWidth = attributedDisconnect.size().width + titlePadding * 2
        let widths = [minWidth, countryWidth, connectWidth, disconnectWidth]
        return 2 * round((widths.max() ?? fallBackWidth) / 2) // prevents bluring on non-retina
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
    
    func appStateChanged(to appState: AppState) {
        if !appState.isStable {
            state = .idle
        }
        viewStateChange?()
    }

    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .text:
            return available ? .normal : [.interactive, .weak, .disabled]
        case .background:
            guard isConnected else {
                return .weak
            }
            return .interactive
        case .icon:
            guard isConnected else {
                guard available else {
                    return [.interactive, .weak]
                }
                return state == .hovered ? .normal : [.interactive, .active]
            }
            return state == .hovered ? [.interactive, .active] : .normal
        default:
            break
        }
        assertionFailure("Context not handled: \(context)")
        return .normal
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
            && appStateManager.activeConnection()?.server.isSecureCore == false
            && appStateManager.activeConnection()?.server.countryCode == countryCode
    }
    
    func countryConnectAction() {
        if isConnected {
            log.debug("Disconnect requested by pressing on country on the map.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            let serverType = ServerType.standard
            log.debug("Connect requested by pressing on a country on the map. Will connect to country: \(countryCode) serverType: \(serverType)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(country: countryCode, ofType: serverType)
        }
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
            && appStateManager.activeConnection()?.server.hasSecureCore == true
            && appStateManager.activeConnection()?.server.countryCode == countryCode
    }
    
    init(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol, country: CountryModel, servers: [ServerModel], userTier: Int, coordinate: CLLocationCoordinate2D) {
        self.servers = servers
        super.init(appStateManager: appStateManager, vpnGateway: vpnGateway, country: country, userTier: userTier, coordinate: coordinate)
    }
    
    func serverConnectAction(forRow row: Int) {
        if serverIsConnected(for: row) {
            log.debug("Server on the map clicked. Already connected, so will disconnect from VPN. ", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            log.debug("Server on the map clicked. Will connect to \(servers[row].logDescription)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(server: servers[row])
        }
    }
    
    func matches(_ code: String) -> Bool {
        return countryCode == code
    }
    
    func attributedServer(for row: Int) -> NSAttributedString {
        guard servers.count > row else { return NSAttributedString() }
        let font = NSFont.themeFont()
        let doubleArrows = AppTheme.Icon.chevronsRight.asAttachment(style: available ? .normal : .weak, size: .square(14), centeredVerticallyForFont: font)
        let serverName = (" " + servers[row].name).styled(available ? .normal : [.interactive, .weak, .disabled], font: font)
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
            && appStateManager.activeConnection()?.server.countryCode == servers[row].countryCode
            && appStateManager.activeConnection()?.server.entryCountryCode == servers[row].entryCountryCode
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
            && appStateManager.activeConnection()?.server.hasSecureCore == true
            && appStateManager.activeConnection()?.server.entryCountryCode == countryCode
    }
    
    override var attributedCountry: NSAttributedString {
        return LocalizedString.secureCoreCountry(LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable).styled()
    }
    
    override var buttonWidth: CGFloat {
        return 2 * round((attributedCountry.size().width + titlePadding * 2) / 2)
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

    override func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .text:
            return .normal
        case .icon:
            return [.interactive, .active]
        case .background:
            return isConnected ? [.interactive, .active] : .weak
        default:
            break
        }
        assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
