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
    private let appStateManager: AppStateManager
    private let factory: WidgetFactory
    private var vpnGateway: VpnGatewayProtocol?
    private var timer: Timer?
    private var connectionFailed = false
    
    init( _ factory: WidgetFactory ){
        self.appStateManager = factory.appStateManager
        self.factory = factory
    }
    
    func viewDidLoad() {
        factory.refreshVpnManager()
        vpnGateway = factory.vpnGateway
        
        guard vpnGateway != nil else {
            viewController?.displayNoGateWay()
            return
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: VpnGateway.connectionChanged, object: nil)
        reachability?.whenReachable = { [weak self] _ in self?.connectionChanged() }
        reachability?.whenUnreachable = { [weak self] _ in self?.viewController?.displayUnreachable() }
        try? reachability?.startNotifier()
    }
    
    func viewWillAppear(_ animated: Bool) {
        ProfileManager.shared.refreshProfiles()
        connectionChanged()
    }
    
    func viewWillDisappear(_ animated: Bool) {
        timer?.invalidate()
        timer = nil
    }
    
    deinit { reachability?.stopNotifier() }
    
    // MARK: - Utils
    
    @objc private func connectionChanged() {
        timer?.invalidate()
        timer = nil
        connectionFailed = false
        
        if let reachability = reachability, reachability.connection == .none {
            viewController?.displayUnreachable()
            return
        }
                
        guard let vpnGateway = vpnGateway else {
            viewController?.displayNoGateWay()
            return
        }

        switch vpnGateway.connection {
        case .connected:
            connectionFailed = false
            displayConnectionState()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { self?.displayConnectionState() }
            }
            
        case .connecting:
            connectionFailed = false
            viewController?.displayConnecting()
            
        case .disconnected, .disconnecting:
            if connectionFailed { break }
            viewController?.displayDisconnected()
        }
    }
    
    @objc func connectAction(_ sender: Any) {
        
        guard let vpnGateway = vpnGateway, !connectionFailed else {
            connectionFailed = false
            // not logged in so open the app or the connection failed
            if let url = URL(string: URLConstants.deepLinkBaseUrl) {
                viewController?.extensionOpenUrl(url)
            }
            return
        }
        
        switch vpnGateway.connection {
        case .connected, .connecting:
            if let url = URL(string: URLConstants.deepLinkDisconnectUrl) {
                viewController?.extensionOpenUrl(url)
            }
        case .disconnected, .disconnecting:
            if let url = URL(string: URLConstants.deepLinkConnectUrl) {
                viewController?.extensionOpenUrl(url)
            }
        }
    }
    
    private func displayConnectionState() {
        switch vpnGateway?.connection {
        case .connected:
            guard let server = appStateManager.activeConnection()?.server else {
                connectionFailed = true
                timer?.invalidate()
                timer = nil
                viewController?.displayError()
                break
            }
            let country = LocalizationUtility.countryName(forCode: server.countryCode)
            let ip = server.ips.first?.entryIp
            viewController?.displayConnected(ip, country: country)
            break
        default:
            break
        }
    }
}

extension TodayViewModelImplementation: ExtensionAlertServiceDelegate {
    func actionErrorReceived() {
        connectionFailed = true
        viewController?.displayError()
    }
}
