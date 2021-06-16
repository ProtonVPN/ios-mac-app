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

enum TodayViewModelState {
    case blank
    case unreachable
    case error
    case connected(_ server: String?, entryCountry: String?, country: String?)
    case disconnected
    case connecting
    case noGateway
}

protocol TodayViewModelDelegate: AnyObject {
    func didChangeState(state: TodayViewModelState)
    func didRequestUrl(url: URL)
}

final class TodayViewModel {
    private var reachability: Reachability?
    private var timer: Timer?
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnManager: VpnManagerProtocol

    weak var delegate: TodayViewModelDelegate?
    
    init(propertiesManager: PropertiesManagerProtocol, vpnManager: VpnManagerProtocol) {
        self.propertiesManager = propertiesManager
        self.vpnManager = vpnManager

        reachability = try? Reachability()
        reachability?.whenReachable = { [weak self] _ in self?.connectionChanged() }
        reachability?.whenUnreachable = { [weak self] _ in self?.delegate?.didChangeState(state: .unreachable) }
        try? reachability?.startNotifier()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.connectionChanged()
        })
    }
    
    func update() {
        connectionChanged()
    }

    func connect() {
        guard propertiesManager.hasConnected else {
            if let url = URL(string: URLConstants.deepLinkBaseUrl) {
                delegate?.didRequestUrl(url: url)
            }
            return
        }

        switch vpnManager.state {
        case .connected, .connecting:
            if let url = URL(string: URLConstants.deepLinkDisconnectUrl) {
                delegate?.didRequestUrl(url: url)
            }
        default:
            if let url = URL(string: URLConstants.deepLinkConnectUrl) {
                delegate?.didRequestUrl(url: url)
            }
        }
    }
    
    deinit { reachability?.stopNotifier() }
    
    // MARK: - Utils
    
    private func displayConnected() {
        guard let connection = activeConnection() else {
            delegate?.didChangeState(state: .disconnected)
            return
        }
                
        let server = connection.server
        let country = LocalizationUtility.default.countryName(forCode: server.countryCode)
        let ip = connection.serverIp.exitIp

        delegate?.didChangeState(state: .connected(ip, entryCountry: server.isSecureCore ? server.entryCountryCode : nil, country: country))
    }

    private func activeConnection() -> ConnectionConfiguration? {
        guard let currentVpnProtocol = vpnManager.currentVpnProtocol else {
            return nil
        }

        switch currentVpnProtocol {
        case .ike:
            return propertiesManager.lastIkeConnection
        case .openVpn:
            return propertiesManager.lastOpenVpnConnection
        }
    }
    
    @objc private func connectionChanged() {
        if let reachability = reachability, reachability.connection == .unavailable {
            delegate?.didChangeState(state: .unreachable)
            return
        }
        
        guard propertiesManager.hasConnected else {
            delegate?.didChangeState(state: .noGateway)
            return
        }
        
        vpnManager.refreshManagers()
        vpnManager.refreshState()
        
        switch vpnManager.state {
        case .connected:
            displayConnected()
        case .connecting:
            delegate?.didChangeState(state: .connecting)
        case .disconnected, .disconnecting, .invalid, .reasserting, .error:
            delegate?.didChangeState(state: .disconnected)
        }
    }
}

extension TodayViewModel: ExtensionAlertServiceDelegate {
    func actionErrorReceived() {
        delegate?.didChangeState(state: .error)
    }
}
