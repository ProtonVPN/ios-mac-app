//
//  DoH.swift
//  vpncore - Created on 22.02.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import ProtonCore_Doh

public protocol DoHVPNFactory {
    func makeDoHVPN() -> DoHVPN
}

public class DoHVPN: DoH, ServerConfig {
    public let liveURL: String = "https://api.protonvpn.ch"
    public let signupDomain: String = "protonmail.com"
    public let defaultPath: String = ""
    public var defaultHost: String {
        #if RELEASE
        return liveURL
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

        guard let url = URL(string: defaultHost), let host = url.host else {
            return ""
        }

        return "https://verify.\(host)"
    }

    public var alternativeRouting: Bool {
        get {
            return status == .on
        }
        set {
            status = newValue ? .on : .off            
        }
    }

    private let customApiHost: String
    private let verifyHost: String
    private let customHost: String?

    public init(apiHost: String, verifyHost: String, alternativeRouting: Bool, customHost: String? = nil) {
        self.customApiHost = apiHost
        self.verifyHost = verifyHost
        self.customHost = customHost
        super.init()

        status = alternativeRouting ? .on : .off
    }
}

public extension DoHVPN {
    static let mock = DoHVPN(apiHost: "", verifyHost: "", alternativeRouting: false)
}
