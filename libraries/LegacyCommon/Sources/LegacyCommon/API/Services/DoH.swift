//
//  DoH.swift
//  vpncore - Created on 22.02.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import ProtonCoreDoh

public protocol DoHVPNFactory {
    func makeDoHVPN() -> DoHVPN
}

public class DoHVPN: DoH, ServerConfig {
    public var proxyToken: String?
    public let liveURL: String = "https://vpn-api.proton.me"
    public let signupDomain: String = "protonmail.com"
    public let defaultPath: String = ""
    public var defaultHost: String {
        #if RELEASE
        if !Bundle.isTestflightBeta {
            return liveURL
        }
        #endif

        return customHost ?? liveURL
    }
    public var captchaHost: String {
        return defaultHost
    }
    public var apiHost: String {
        return customApiHost
    }
    public var statusHost: String {
        return "http://protonstatus.com"
    }

    public var humanVerificationV3Host: String {
        if defaultHost == liveURL {
            return verifyHost
        }

        // some test servers are hosted on a vpn subdomain that is not used for the verify host
        guard let url = URL(string: defaultHost.replacingOccurrences(of: "vpn.", with: "")), let host = url.host else {
            return ""
        }

        return "https://verify.\(host)"
    }

    public var alternativeRouting: Bool {
        didSet {
            settingsUpdated()
        }
    }

    private var appState: AppState {
        didSet {
            settingsUpdated()
        }
    }

    public var accountHost: String {
        if defaultHost == liveURL {
            return "https://account.proton.me"
        }

        // some test servers are hosted on a vpn subdomain that is not used for the account host
        guard let url = URL(string: defaultHost.replacingOccurrences(of: "vpn.", with: "")), let host = url.host else {
            return ""
        }

        return "https://account.\(host)"
    }

    private let customApiHost: String
    private let verifyHost: String
    private let customHost: String?

    public let atlasSecret: String?

    public var isAtlasRequest: Bool {
        return defaultHost != liveURL
    }

    public init(apiHost: String, verifyHost: String, alternativeRouting: Bool, customHost: String? = nil, atlasSecret: String? = nil, appState: AppState) {
        self.customApiHost = apiHost
        self.verifyHost = verifyHost
        self.customHost = customHost
        self.atlasSecret = atlasSecret
        self.alternativeRouting = alternativeRouting
        self.appState = appState
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: .AppStateManager.stateChange, object: nil)

        status = alternativeRouting ? .on : .off
    }

    @objc private func stateChanged(notification: Notification) {
        guard let newState = notification.object as? AppState else {
            return
        }
        appState = newState
    }

    private func settingsUpdated() {
        if case .connected = appState {
            if status == .on {
                log.debug("Disabling DoH while connected to VPN", category: .api)
            }
            status = .off
        } else {
            if status == .off, alternativeRouting {
                log.debug("Re-enabling DoH while disconnected from VPN", category: .api)
            }
            status = alternativeRouting ? .on : .off
        }
    }
}

public extension DoHVPN {
    static let mock = DoHVPN(apiHost: "", verifyHost: "", alternativeRouting: false, appState: .disconnected)
}
