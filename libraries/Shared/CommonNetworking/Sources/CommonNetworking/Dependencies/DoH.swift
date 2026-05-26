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

import Dependencies
import Domain
import Foundation
import Logging
import ProtonCoreDoh

public class DoHVPN: DoH, ServerConfig {
    public var proxyToken: String? {
        atlasSecret
    }

    public let liveURL: String = "https://vpn-api.proton.me"
    public let signupDomain: String = "protonmail.com"
    public let defaultPath: String = ""
    public var defaultHost: String {
        guard let customHost else {
            return liveURL
        }

        // In RELEASE, verify the host is valid and a domain we control.
        // This dependency is defined in this module, and by default validates using prod/release rules.
        // It is meant to be overridden in app targets where we have the ability to distinguish between Staging and
        // Release builds.
        @Dependency(\.customHostValidator) var validator
        do {
            try validator.validate(customHost)
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
    }

    public var captchaHost: String {
        defaultHost
    }

    public var apiHost: String {
        customApiHost
    }

    public var statusHost: String {
        "http://protonstatus.com"
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
    private var connectionStatusTask: Task<Void, Never>?

    public let atlasSecret: String?

    private var atlasHeader: [String: String] {
        guard let atlasSecret, isAtlasRequest else { return [:] }
        return ["x-atlas-secret": atlasSecret]
    }

    public var isAtlasRequest: Bool {
        defaultHost != liveURL
    }

    public init<S: AsyncSequence & Sendable>(
        apiHost: String,
        verifyHost: String,
        alternativeRouting: Bool,
        customHost: String? = nil,
        atlasSecret: String? = nil,
        isConnected: Bool,
        connectionStatusStream: @escaping @Sendable () -> S
    ) where S.Element == Bool {
        self.customApiHost = apiHost
        self.verifyHost = verifyHost
        self.customHost = customHost
        self.atlasSecret = atlasSecret
        self.alternativeRouting = alternativeRouting
        self.isConnected = isConnected
        super.init()

        self.connectionStatusTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await connected in connectionStatusStream() {
                    self.isConnected = connected
                }
            } catch {
                log.error("Connection status stream failed", category: .api, metadata: ["error": "\(error)"])
            }
        }

        status = alternativeRouting ? .on : .off
    }

    /// Convenience initializer used when a connection status stream isn't required (e.g. tests, mocks).
    public convenience init(
        apiHost: String,
        verifyHost: String,
        alternativeRouting: Bool,
        customHost: String? = nil,
        atlasSecret: String? = nil,
        isConnected: Bool
    ) {
        self.init(
            apiHost: apiHost,
            verifyHost: verifyHost,
            alternativeRouting: alternativeRouting,
            customHost: customHost,
            atlasSecret: atlasSecret,
            isConnected: isConnected,
            connectionStatusStream: { AsyncStream<Bool>.finished }
        )
    }

    override public func getHumanVerificationV3Headers() -> [String: String] {
        super.getHumanVerificationV3Headers()
            .merging(atlasHeader, uniquingKeysWith: { _, rhs in rhs })
    }

    override public func getAccountHeaders() -> [String: String] {
        super.getAccountHeaders()
            .merging(atlasHeader, uniquingKeysWith: { _, rhs in rhs })
    }

    override public func getCaptchaHeaders() -> [String: String] {
        super.getCaptchaHeaders()
            .merging(atlasHeader, uniquingKeysWith: { _, rhs in rhs })
    }

    deinit {
        connectionStatusTask?.cancel()
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
        isConnected: false
    )
}

public enum DoHConfigurationKey: TestDependencyKey {
    public static var testValue: DoHVPN {
        .mock
    }
}

public extension DependencyValues {
    var dohConfiguration: DoHVPN {
        get { self[DoHConfigurationKey.self] }
        set { self[DoHConfigurationKey.self] = newValue }
    }
}
