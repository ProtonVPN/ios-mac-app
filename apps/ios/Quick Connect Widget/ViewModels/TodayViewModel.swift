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
    private var timer: Timer?
    private let propertiesManager: PropertiesManager
    private let vpnManager: VpnManagerProtocol
    
    init( _ propertiesManager: PropertiesManager, vpnManager: VpnManagerProtocol ){
        self.propertiesManager = propertiesManager
        self.vpnManager = vpnManager
    }
    
    func viewDidLoad() {
        reachability?.whenReachable = { [weak self] _ in self?.connectionChanged() }
        reachability?.whenUnreachable = { [weak self] _ in self?.viewController?.displayUnreachable() }
        try? reachability?.startNotifier()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.connectionChanged()
        })
    }
    
    func viewWillAppear(_ animated: Bool) {
        connectionChanged()
    }
    
    deinit { reachability?.stopNotifier() }
    
    // MARK: - Utils
    
    private func displayConnected() {
        guard let request = propertiesManager.lastConnectionRequest,
            let connection = request.vpnProtocol == .ike ? propertiesManager.lastIkeConnection : propertiesManager.lastOpenVpnConnection else {
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
        
        guard propertiesManager.hasConnected else {
            viewController?.displayNoGateWay()
            return
        }
        
        vpnManager.refreshManagers()
        vpnManager.refreshState()
        
        switch vpnManager.state {
        case .connected:
            displayConnected()
        case .connecting:
            viewController?.displayConnecting()
        case .disconnected, .disconnecting:
            viewController?.displayDisconnected()
        default:
            viewController?.displayDisconnected()
            break
        }
    }
    
    @objc func connectAction(_ sender: Any) {
        guard propertiesManager.hasConnected else {
            if let url = URL(string: URLConstants.deepLinkBaseUrl) {
                viewController?.extensionOpenUrl(url)
            }
            return
        }
        
        switch vpnManager.state {
        case .connected, .connecting:
            if let url = URL(string: URLConstants.deepLinkDisconnectUrl) {
                viewController?.extensionOpenUrl(url)
            }
        default:
            if let url = URL(string: URLConstants.deepLinkConnectUrl) {
                viewController?.extensionOpenUrl(url)
            }
        }
    }
}

extension TodayViewModelImplementation: ExtensionAlertServiceDelegate {
    func actionErrorReceived() {
        viewController?.displayError()
    }
}
