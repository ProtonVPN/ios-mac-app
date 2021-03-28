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
import PMNetworking

class DoHVPN: DoH, ServerConfig {
    private let propertiesManager = PropertiesManager()

    let liveURL: String = "https://api.protonvpn.ch" // do not change to development url due to IAP restriction
    let signupDomain: String = "protonmail.com"
    let captchaHost: String = "secure.protonmail.com"
    let defaultPath: String = ""
    var defaultHost: String {
        #if RELEASE
        return liveURL
        #endif

        return propertiesManager.apiEndpoint ?? liveURL
    }
    var apiHost: String {
        return customApiHost
    }
    let statusHost: String = "http://protonstatus.com"

    private var customApiHost: String

    init(apiHost: String) throws {
        self.customApiHost = apiHost
        try super.init()

        // Setting status to On. The actual usage of alternative routing is directed by the usage of the `AlternativeRoutingInterceptor`
        status = .on
    }
}
