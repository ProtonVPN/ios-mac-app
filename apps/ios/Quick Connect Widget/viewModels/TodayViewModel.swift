//
//  TodayViewModel.swift
//  ProtonVPN - Created on 09/04/2020.
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

import Reachability
import vpncore
import NotificationCenter

protocol TodayViewModel: GenericViewModel {
    var viewController: TodayViewControllerProtocol? { get set }
    func connectAction( _ sender: Any )
}

class TodayViewModelImplementation: TodayViewModel {
    
    weak var viewController: TodayViewControllerProtocol?
    
    private let reachability = Reachability()
    private let factory: WidgetFactory
//    private var vpnGateway: VpnGatewayProtocol?
    
    init( _ factory: WidgetFactory ){
        self.factory = factory
    }
    
    func viewDidLoad() {
        factory.refreshVpnManager()
//        vpnGateway = factory.vpnGateway
        
//        guard vpnGateway != nil else {
//            viewController?.displayNoGateWay()
//            return
//        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: VpnGateway.connectionChanged, object: nil)
        reachability?.whenReachable = { [weak self] _ in self?.connectionChanged() }
        reachability?.whenUnreachable = { [weak self] _ in self?.viewController?.displayUnreachable() }
        try? reachability?.startNotifier()
    }
    
    func viewWillAppear(_ animated: Bool) {
        ProfileManager.shared.refreshProfiles()
        factory.refreshVpnManager()
        connectionChanged()
    }
    
    deinit { reachability?.stopNotifier() }
    
    // MARK: - Utils
    
    private func displayConnection() {
        let properties = factory.propertiesManager
        guard let request = properties.lastConnectionRequest,
            let connection = request.vpnProtocol == .ike ? properties.lastIkeConnection : properties.lastOpenVpnConnection else {
                viewController?.displayNoGateWay()
                return
        }
        
        let server = connection.server
        let country = LocalizationUtility.default.countryName(forCode: server.countryCode)
        let ip = server.ips.first?.exitIp
        viewController?.displayConnected(ip, entryCountry: server.isSecureCore ? server.entryCountryCode : nil, country: country)
    }
    
    @objc private func connectionChanged() {
        
        if let reachability = reachability, reachability.connection == .none {
            viewController?.displayUnreachable()
            return
        }
         
        

        
//        viewController?.displayNoGateWay()
        displayConnection()
//        guard let vpnGateway = vpnGateway else {
//            viewController?.displayNoGateWay()
//            return
//        }
//
//        switch vpnGateway.connection {
//        case .connected:
//            let server = appStateManager.activeConnection()?.server
//            let country = LocalizationUtility.default.countryName(forCode: server?.countryCode ?? "")
//            let ip = server?.ips.first?.entryIp
//            viewController?.displayConnected(ip, country: country)
//
//        case .connecting:
//            viewController?.displayConnecting()
//
//        case .disconnected, .disconnecting:
//            viewController?.displayDisconnected()
//        }
    }
    
    @objc func connectAction(_ sender: Any) {
        
//        guard let vpnGateway = vpnGateway else {
//            // not logged in so open the app or the connection failed
//            if let url = URL(string: URLConstants.deepLinkBaseUrl) {
//                viewController?.extensionOpenUrl(url)
//            }
//            return
//        }
//
//        switch vpnGateway.connection {
//        case .connected, .connecting:
//            if let url = URL(string: URLConstants.deepLinkDisconnectUrl) {
//                viewController?.extensionOpenUrl(url)
//            }
//        case .disconnected, .disconnecting:
//            if let url = URL(string: URLConstants.deepLinkConnectUrl) {
//                viewController?.extensionOpenUrl(url)
//            }
//        }
    }
}

extension TodayViewModelImplementation: ExtensionAlertServiceDelegate {
    func actionErrorReceived() {
        viewController?.displayError()
    }
}
