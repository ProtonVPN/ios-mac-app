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
    
    private var reachability: Reachability?
    private var timer: Timer?
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnManager: VpnManagerProtocol
    private let appStateManager: AppStateManager
    
    init( _ propertiesManager: PropertiesManagerProtocol, vpnManager: VpnManagerProtocol, appStateManager: AppStateManager ){
        self.propertiesManager = propertiesManager
        self.vpnManager = vpnManager
        self.appStateManager = appStateManager
    }
    
    func viewDidLoad() {
        reachability = try? Reachability()
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
        guard let connection = appStateManager.activeConnection() else {
                viewController?.displayDisconnected()
                return
        }
                
        let server = connection.server
        let country = LocalizationUtility.default.countryName(forCode: server.countryCode)
        let ip = connection.serverIp.exitIp
        
        viewController?.displayConnected(ip, entryCountry: server.isSecureCore ? server.entryCountryCode : nil, country: country)
    }
    
    @objc private func connectionChanged() {
        
        if let reachability = reachability, reachability.connection == .unavailable {
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
