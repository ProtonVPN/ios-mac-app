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
import vpncore

class CountryAnnotationViewModel: AnnotationViewModel {
    
    enum ViewState {
        case idle
        case selected
    }
    
    private let countryModel: CountryModel
    private let serverModels: [ServerModel]
    private var vpnGateway: VpnGatewayProtocol?
    private let appStateManager: AppStateManager
    private let alertService: AlertService
    private let loginService: LoginService
    
    private let requiresUpgrade: Bool
    
    var buttonStateChanged: (() -> Void)?
    var countryTapped: ((CountryAnnotationViewModel) -> Void)?
    
    var coordinate: CLLocationCoordinate2D {
        return countryModel.location
    }
    
    let serverType: ServerType
    
    /// Under maintenance if all servers are
    var underMaintenance: Bool {
        return !serverModels.contains { !$0.underMaintenance }
    }
    
    var available: Bool {
        return !requiresUpgrade && !underMaintenance
    }
    
    var viewState: AnnotationViewState = .idle {
        didSet {
            if oldValue != viewState { // to prevent excessive draw calls
                DispatchQueue.main.async { [unowned self] in
                    self.buttonStateChanged?()
                }
            }
        }
    }
    
    var countryCode: String {
        return countryModel.countryCode
    }
    
    var isConnected: Bool {
        if let vpnGateway = vpnGateway, vpnGateway.connection == .connected, let activeServer = appStateManager.activeConnection()?.server, activeServer.serverType == serverType, activeServer.countryCode == countryCode {
            return true
        }
        return false
    }
    
    var isConnecting: Bool {
        if let vpnGateway = vpnGateway, let activeConnection = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting, case ConnectionRequestType.country(let activeCountryCode, _) = activeConnection.connectionType, activeCountryCode == countryCode {
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
        if requiresUpgrade || underMaintenance {
            return .protonMapGrey()
        } else if connectedUiState {
            return .protonConnectGreen()
        } else {
            return .protonWhite()
        }
    }
    
    var labelColor: UIColor {
        if connectedUiState {
            return UIColor.protonConnectGreen().withAlphaComponent(0.75)
        } else {
            return UIColor.protonMapGrey().withAlphaComponent(0.75)
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
            return .protonConnectGreen()
        } else {
            return .protonWhite()
        }
    }
    
    var connectIcon: UIImage? {
        if requiresUpgrade {
            switch viewState {
            case .idle:
                return nil
            case .selected:
                return UIImage(named: "locked")
            }
        } else if connectedUiState {
            return UIImage(named: "connect")?.withRenderingMode(.alwaysTemplate)
        } else {
            switch viewState {
            case .idle:
                return nil
            case .selected:
                return UIImage(named: "connect")?.withRenderingMode(.alwaysTemplate)
            }
        }
    }
    
    let showAnchor: Bool = true
    
    init(countryModel: CountryModel, servers: [ServerModel], serverType: ServerType, vpnGateway: VpnGatewayProtocol?, appStateManager: AppStateManager, enabled: Bool, alertService: AlertService, loginService: LoginService) {
        self.countryModel = countryModel
        self.serverModels = servers
        self.vpnGateway = vpnGateway
        self.appStateManager = appStateManager
        self.requiresUpgrade = !enabled
        self.alertService = alertService
        self.loginService = loginService
        self.serverType = serverType
        
        startObserving()
    }
    
    func tapped() {
        switch viewState {
        case .idle:
            viewState = .selected
        case .selected:
            guard let vpnGateway = vpnGateway else {
                loginService.presentSignup()
                return
            }
            
            if underMaintenance {
                alertService.push(alert: MaintenanceAlert(countryName: labelString.string))
            } else if isConnected {
                vpnGateway.disconnect()
            } else if isConnecting {
                vpnGateway.stopConnecting(userInitiated: true)
            } else {
                vpnGateway.connectTo(country: countryCode, ofType: serverType)
            }
        }
        
        countryTapped?(self)
    }
    
    func deselect() {
        viewState = .idle
    }
    
    // MARK: - Private functions
    fileprivate func startObserving() {
        guard vpnGateway != nil else { return }
        
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    private func formDescription() -> NSAttributedString {
        let country = LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable
        return country.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = buttonStateChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
    }
}
