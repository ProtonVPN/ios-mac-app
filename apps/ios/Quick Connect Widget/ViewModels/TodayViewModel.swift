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
    private let vpnStateConfiguration: VpnStateConfiguration

    weak var delegate: TodayViewModelDelegate?
    
    init(vpnStateConfiguration: VpnStateConfiguration) {
        self.vpnStateConfiguration = vpnStateConfiguration

        reachability = try? Reachability()
        reachability?.whenReachable = { [weak self] _ in self?.connectionChanged() }
        reachability?.whenUnreachable = { [weak self] _ in self?.delegate?.didChangeState(state: .unreachable) }
        try? reachability?.startNotifier()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.connectionChanged()
        })
    }
    
    func update(completion: (()-> Void)? = nil) {
        connectionChanged(completion: completion)
    }

    func connect() {
        vpnStateConfiguration.getInfo { [weak self] info in
            guard info.hasConnected else {
                if let url = URL(string: URLConstants.deepLinkBaseUrl) {
                    self?.delegate?.didRequestUrl(url: url)
                }
                return
            }

            switch info.state {
            case .connected, .connecting:
                if let url = URL(string: URLConstants.deepLinkDisconnectUrl) {
                    self?.delegate?.didRequestUrl(url: url)
                }
            default:
                if let url = URL(string: URLConstants.deepLinkConnectUrl) {
                    self?.delegate?.didRequestUrl(url: url)
                }
            }
        }
    }
    
    deinit {
        reachability?.stopNotifier()        
    }
    
    // MARK: - Utils
    
    @objc private func connectionChanged(completion: (()-> Void)? = nil) {
        if let reachability = reachability, reachability.connection == .unavailable {
            delegate?.didChangeState(state: .unreachable)
            completion?()
            return
        }

        vpnStateConfiguration.getInfo { [weak self] info in
            guard info.hasConnected else {
                self?.delegate?.didChangeState(state: .noGateway)
                completion?()
                return
            }

            switch info.state {
            case .connected:
                guard let activeConection = info.connection else {
                    completion?()
                    return
                }

                self?.delegate?.didChangeState(state: .connected(activeConection.serverIp.exitIp, entryCountry: activeConection.server.isSecureCore ? activeConection.server.entryCountryCode : nil, country: LocalizationUtility.default.countryName(forCode: activeConection.server.countryCode)))
                completion?()
            case .connecting:
                self?.delegate?.didChangeState(state: .connecting)
                completion?()
            case .disconnected, .disconnecting, .invalid, .reasserting, .error:
                self?.delegate?.didChangeState(state: .disconnected)
                completion?()
            }
        }
    }
}

extension TodayViewModel: ExtensionAlertServiceDelegate {
    func actionErrorReceived() {
        delegate?.didChangeState(state: .error)
    }
}
