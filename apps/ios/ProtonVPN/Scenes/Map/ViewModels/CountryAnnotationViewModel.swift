//
//  CountryAnnotationViewModel.swift
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

import CoreLocation
import UIKit

import Domain
import Strings

import LegacyCommon

class CountryAnnotationViewModel: AnnotationViewModel {
    
    enum ViewState {
        case idle
        case selected
    }
    
    private let countryModel: CountryModel
    private let groupInfo: ServerGroupInfo
    private let serverType: ServerType
    private var vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager
    private let alertService: AlertService
    private let connectionStatusService: ConnectionStatusService
    
    private let requiresUpgrade: Bool
    
    var buttonStateChanged: (() -> Void)?
    var countryTapped: ((CountryAnnotationViewModel) -> Void)?
    
    var coordinate: CLLocationCoordinate2D {
        return countryModel.location
    }
    
    /// Under maintenance if all servers are
    var underMaintenance: Bool {
        return groupInfo.isUnderMaintenance
    }
    
    var available: Bool {
        return !requiresUpgrade && !underMaintenance
    }
    
    var viewState: AnnotationViewState = .idle {
        didSet {
            if oldValue != viewState { // to prevent excessive draw calls
                DispatchQueue.main.async { [weak self] in
                    self?.buttonStateChanged?()
                }
            }
        }
    }

    var countryCode: String {
        return countryModel.countryCode
    }
    
    var isConnected: Bool {
        if vpnGateway.connection == .connected, let activeServer = appStateManager.activeConnection()?.server, activeServer.serverType == serverType, activeServer.countryCode == countryCode {
            return true
        }
        return false
    }
    
    var isConnecting: Bool {
        if let activeConnection = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting, case ConnectionRequestType.country(let activeCountryCode, _) = activeConnection.connectionType, activeCountryCode == countryCode {
            return true
        }
        return false
    }
    
    var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    var description: NSAttributedString {
        return formDescription()
    }
    
    let minPinHeight: CGFloat = 44
    let maxPinHeight: CGFloat = 60
    
    var anchorPoint: CGPoint {
        return CGPoint(x: 0.5, y: maxPinHeight / maxHeight)
    }
    
    var outlineColor: UIColor {
        if connectedUiState {
            return .brandColor()
        } else if requiresUpgrade || underMaintenance {
            return .weakInteractionColor()
        } else {
            return .normalTextColor()
        }
    }
    
    var labelColor: UIColor {
        if connectedUiState {
            return UIColor.brandColor().withAlphaComponent(0.75)
        } else {
            return UIColor.weakInteractionColor().withAlphaComponent(0.75)
        }
    }
    
    var flagOverlayColor: UIColor {
        if requiresUpgrade || underMaintenance || isConnected || isConnecting {
            return UIColor.black.withAlphaComponent(0.75)
        } else {
            switch viewState {
            case .idle:
                return UIColor.clear
            case .selected:
                return UIColor.black.withAlphaComponent(0.75)
            }
        }
    }
    
    var connectIconTint: UIColor {
        if connectedUiState {
            return .brandColor()
        } else {
            return .normalTextColor()
        }
    }
    
    var connectIcon: UIImage? {
        if connectedUiState {
            return Asset.connect.image.withRenderingMode(.alwaysTemplate)
        } else if requiresUpgrade {
            switch viewState {
            case .idle:
                return nil
            case .selected:
                return Asset.locked.image
            }
        } else {
            switch viewState {
            case .idle:
                return nil
            case .selected:
                return Asset.connect.image.withRenderingMode(.alwaysTemplate)
            }
        }
    }
    
    let showAnchor: Bool = true
    
    init(
        countryModel: CountryModel,
        groupInfo: ServerGroupInfo,
        serverType: ServerType,
        vpnGateway: VpnGatewayProtocol,
        appStateManager: AppStateManager,
        enabled: Bool,
        alertService: AlertService,
        connectionStatusService: ConnectionStatusService
    ) {
        self.countryModel = countryModel
        self.groupInfo = groupInfo
        self.serverType = serverType
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        self.requiresUpgrade = !enabled
        self.alertService = alertService
        self.connectionStatusService = connectionStatusService
        
        startObserving()
    }
    
    func tapped() {
        switch viewState {
        case .idle:
            viewState = .selected
        case .selected:
            log.debug("Connect requested by clicking on Country in the map", category: .connectionConnect, event: .trigger)
            
            if underMaintenance {
                log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
                alertService.push(alert: MaintenanceAlert(countryName: labelString.string))
            } else if isConnected {
                log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
                NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.map))
                vpnGateway.disconnect()
            } else if isConnecting {
                NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.abort)
                log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
                vpnGateway.stopConnecting(userInitiated: true)
            } else {
                NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
                log.debug("Will connect to country: \(countryCode) serverType: \(serverType)", category: .connectionConnect, event: .trigger)
                vpnGateway.connectTo(country: countryCode, ofType: serverType, trigger: .map)
                connectionStatusService.presentStatusViewController()
            }
        }
        
        countryTapped?(self)
    }
    
    func deselect() {
        viewState = .idle
    }
    
    // MARK: - Private functions
    fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    private func formDescription() -> NSAttributedString {
        let country = LocalizationUtility.default.countryName(forCode: countryCode) ?? Localizable.unavailable
        return country.attributed(withColor: .normalTextColor(), fontSize: 16, alignment: .left)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = buttonStateChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
    }
}
