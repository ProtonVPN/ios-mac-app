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
import Dependencies
import ProtonCoreDoh
import Logging

import Domain

public enum CustomHostValidator {
    public static func validate(customHost: String) throws (ValidationFailure) {
        let controlledDomains = ["proton.black"]
        // Only allow custom hosts using a domain we control.
        guard let url = URL(string: customHost) else {
            throw .invalidURL
        }

        guard let host = url.host else {
            throw .invalidHost
        }

        let isControlledDomain = controlledDomains.contains { host.hasSuffix($0) }
        guard isControlledDomain else {
            throw .uncontrolledDomain
        }
    }

    public enum ValidationFailure: Error, Equatable, CustomStringConvertible {
        case invalidURL
        case invalidHost
        case uncontrolledDomain

        public var description: String {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidHost:
                return "Invalid Host"
            case .uncontrolledDomain:
                return "Uncontrolled Domain"
            }
        }
    }
}

public class DoHVPN: DoH, ServerConfig {
    public var proxyToken: String?
    public let liveURL: String = "https://vpn-api.proton.me"
    public let signupDomain: String = "protonmail.com"
    public let defaultPath: String = ""
    public var defaultHost: String {
        guard let customHost else {
            return liveURL
        }

#if VALIDATE_CUSTOM_HOST
        // In RELEASE, verify the host is valid and a domain we control
        do {
            try CustomHostValidator.validate(customHost: customHost)
            log.debug("Allowing custom host", category: .api, metadata: ["customHost": "\(customHost)"])
            return customHost
        } catch {
            log.debug(
                "Rejecting custom host, falling back to default live url",
                category: .api,
                metadata: ["customHost": "\(customHost)", "error": "\(error)"]
            )
            return liveURL
        }
#else
        // Allow any host in DEBUG & STAGING
        return customHost
#endif
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

    public let isAppStateNotificationConnected: ((Notification) -> Bool)

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

    private var isConnected: Bool {
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

    private var atlasHeader: [String: String] {
        guard let atlasSecret, isAtlasRequest else { return [:] }
        return ["x-atlas-secret": atlasSecret]
    }

    public var isAtlasRequest: Bool {
        return defaultHost != liveURL
    }

    public init(
        apiHost: String,
        verifyHost: String,
        alternativeRouting: Bool,
        customHost: String? = nil,
        atlasSecret: String? = nil,
        isConnected: Bool,
        isAppStateNotificationConnected: @escaping (Notification) -> Bool
    ) {
        self.customApiHost = apiHost
        self.verifyHost = verifyHost
        self.customHost = customHost
        self.atlasSecret = atlasSecret
        self.alternativeRouting = alternativeRouting
        self.isConnected = isConnected
        self.isAppStateNotificationConnected = isAppStateNotificationConnected
        super.init()

        AppEvent.appStateManagerStateChange.subscribe(self, selector: #selector(stateChanged))

        status = alternativeRouting ? .on : .off
    }

    public override func getHumanVerificationV3Headers() -> [String: String] {
        super.getHumanVerificationV3Headers()
            .merging(atlasHeader, uniquingKeysWith: { _, rhs in rhs })
    }

    public override func getAccountHeaders() -> [String : String] {
        super.getAccountHeaders()
            .merging(atlasHeader, uniquingKeysWith: { _, rhs in rhs })
    }

    public override func getCaptchaHeaders() -> [String : String] {
        super.getCaptchaHeaders()
            .merging(atlasHeader, uniquingKeysWith: { _, rhs in rhs })
    }

    @objc private func stateChanged(notification: Notification) {
        isConnected = isAppStateNotificationConnected(notification)
    }

    private func settingsUpdated() {
        if isConnected {
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
    static let mock = DoHVPN(
        apiHost: "",
        verifyHost: "",
        alternativeRouting: false,
        isConnected: false,
        isAppStateNotificationConnected: { _ in false }
    )
}

public enum DoHConfigurationKey: TestDependencyKey {
    public static var testValue: DoHVPN { .mock }
}

extension DependencyValues {
    public var dohConfiguration: DoHVPN {
        get { self[DoHConfigurationKey.self] }
        set { self[DoHConfigurationKey.self] = newValue }
    }
}
