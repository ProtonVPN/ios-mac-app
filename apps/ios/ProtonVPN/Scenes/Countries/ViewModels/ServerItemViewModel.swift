//
//  ServerItemViewModel.swift
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
import LegacyCommon
import Search
import ProtonCoreUIFoundations
import AlamofireImage
import Strings

class ServerItemViewModel: ServerItemViewModelCore {

    private let alertService: AlertService
    private let connectionStatusService: ConnectionStatusService
    private let planService: PlanService

    var partnersIconsReceipts: [RequestReceipt] = []
    
    var isConnected: Bool {
        if vpnGateway.connection == .connected,
           let activeServer = appStateManager.activeConnection()?.server,
           activeServer.id == serverModel.id {
            return true
        }

        return false
    }
    
    var isConnecting: Bool {
        if let activeConnection = vpnGateway.lastConnectionRequest,
           vpnGateway.connection == .connecting,
           case ConnectionRequestType.country(_, let countryRequestType) = activeConnection.connectionType,
           case CountryConnectionRequestType.server(let activeServer) = countryRequestType,
           activeServer == serverModel {
            return true
        }
        return false
    }
    
    var viaCountry: (name: String, code: String)? {
        return nil
    }
    
    var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    fileprivate var canConnect: Bool {
        return !isUsersTierTooLow && !underMaintenance
    }

    var connectionChanged: (() -> Void)?
    var countryConnectionChanged: Notification.Name?
    
    // MARK: First line in the TableCell
    
    var description: String { return serverModel.name }
    
    var city: String {
        return serverModel.city ?? ""
    }
    
    var loadColor: UIColor {
        if serverModel.load > 90 {
            return .notificationErrorColor()
        } else if serverModel.load > 75 {
            return .notificationWarningColor()
        } else {
            return .notificationOKColor()
        }
    }
    
    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            return IconProvider.lock
        } else if underMaintenance {
            return IconProvider.wrench
        } else {
            return IconProvider.powerOff
        }
    }
    
    var textInPlaceOfConnectIcon: String? {
        return isUsersTierTooLow ? Localizable.upgrade : nil
    }
    
    init(serverModel: ServerModel,
         vpnGateway: VpnGatewayProtocol,
         appStateManager: AppStateManager,
         alertService: AlertService,
         connectionStatusService: ConnectionStatusService,
         propertiesManager: PropertiesManagerProtocol,
         planService: PlanService) {

        self.alertService = alertService
        self.connectionStatusService = connectionStatusService
        self.planService = planService

        super.init(serverModel: serverModel,
                   vpnGateway: vpnGateway,
                   appStateManager: appStateManager,
                   propertiesManager: propertiesManager)
        if canConnect {
            startObserving()
        }
    }
    
    func connectAction() {
        log.debug("Connect requested by clicking on Server item", category: .connectionConnect, event: .trigger)
        
        if underMaintenance {
            log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
            alertService.push(alert: MaintenanceAlert(forSpecificCountry: nil))
        } else if isUsersTierTooLow {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            planService.presentPlanSelection()
        } else if isConnected {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.server))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else if isConnecting {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            log.debug("Will connect to \(serverModel.logDescription)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(server: serverModel)
            connectionStatusService.presentStatusViewController()
        }
    }
    
    // MARK: - Private functions
    fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = connectionChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
    }
}

// MARK: - SecureCoreServerItemViewModel subclass
class SecureCoreServerItemViewModel: ServerItemViewModel {
        
    override var viaCountry: (name: String, code: String)? {
        return isSecureCoreEnabled ? (serverModel.entryCountry, serverModel.entryCountryCode) : nil
    }

    override fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
}

// MARK: - Search

extension ServerItemViewModel: ServerViewModel {

    func cancelPartnersIconRequests() {
        partnersIconsReceipts.forEach {
            $0.request.cancel()
        }
    }

    func partnersIcon(completion: @escaping (UIImage?) -> Void) {
        let iconURLs: [URLRequest] = partners.compactMap {
            guard let iconURL = $0.iconURL else { return nil }
            return URLRequest(url: iconURL)
        }
        guard !iconURLs.isEmpty else { return }

        partnersIconsReceipts = AlamofireImage.ImageDownloader.default.download(iconURLs, completion: { response in
            completion(response.value)
        })
    }

    var connectButtonColor: UIColor {
        if underMaintenance {
            return isUsersTierTooLow ? UIColor.weakInteractionColor() : .clear
        }
        return connectedUiState ? UIColor.interactionNorm() : UIColor.weakInteractionColor()
    }

    var entryCountryName: String? {
        return viaCountry?.name
    }

    var entryCountryFlag: UIImage? {
        guard let code = viaCountry?.code else {
            return nil
        }

        return UIImage.flag(countryCode: code)
    }

    var countryName: String {
        return LocalizationUtility.default.countryName(forCode: serverModel.countryCode) ?? ""
    }

    var countryFlag: UIImage? {
        return UIImage.flag(countryCode: serverModel.countryCode)
    }

    var translatedCity: String? {
        return serverModel.translatedCity
    }

    var textColor: UIColor {
        return UIColor.normalTextColor()
    }
}
