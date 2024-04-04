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

import Foundation
import Reachability
import LegacyCommon
import Localization
import Strings
import os.log

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
    private let vpnStateConfiguration: VpnStateConfiguration
    private let secureDeepLinkGenerator = SecureDeepLinkGenerator()

    weak var delegate: TodayViewModelDelegate?
    
    init(vpnStateConfiguration: VpnStateConfiguration) {
        self.vpnStateConfiguration = vpnStateConfiguration

        reachability = try? Reachability()
        reachability?.whenReachable = { [weak self] _ in self?.connectionChanged() }
        reachability?.whenUnreachable = { [weak self] _ in self?.delegate?.didChangeState(state: .unreachable) }
        try? reachability?.startNotifier()
    }
    
    func update(completion: (() -> Void)? = nil) {
        connectionChanged(completion: completion)
    }

    func connect() {
        vpnStateConfiguration.getInfo { [weak self] info in
            var components = URLComponents()
            components.scheme = URLConstants.deepLinkScheme
            components.host = ""

            guard info.hasConnected else {
                guard let url = components.url else { return }

                // Just protonvpn://
                self?.delegate?.didRequestUrl(url: url)
                return
            }

            let action: String
            switch info.state {
            case .connected, .connecting:
                action = URLConstants.deepLinkDisconnectAction
            default:
                action = URLConstants.deepLinkConnectAction
            }

            components.host = action
            do {
                components.queryItems = try self?.secureDeepLinkGenerator.makeSecureQuery()
            } catch {
                os_log(.error, "Could not generate secure deeplink: %{public}s", String(describing: error))
            }

            guard let url = components.url else { return }
            self?.delegate?.didRequestUrl(url: url)
        }
    }
    
    deinit {
        reachability?.stopNotifier()        
    }
    
    // MARK: - Utils
    
    @objc private func connectionChanged(completion: (() -> Void)? = nil) {
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
