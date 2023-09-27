//
//  URLConstants.swift
//  ProtonVPN - Created on 15/04/2020.
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

struct URLConstants {
    
    private init () { }
    
    // MARK: - DeepLinking

    static let deepLinkScheme = "protonvpn"
    static let deepLinkBaseUrl = "\(deepLinkScheme)://"
    
    static let deepLinkConnectAction = "connect"
    
    static let deepLinkConnectUrl = URLConstants.deepLinkBaseUrl + URLConstants.deepLinkConnectAction
    
    static let deepLinkDisconnectAction = "disconnect"
    
    static let deepLinkDisconnectUrl = URLConstants.deepLinkBaseUrl + URLConstants.deepLinkDisconnectAction
    
    static let deepLinkLoginAction = "login"
    
    static let deepLinkLoginUrl = URLConstants.deepLinkBaseUrl + URLConstants.deepLinkLoginAction

    static let deepLinkRefresh = "refresh"
    static let deepLinkRefreshAccount = "refresh-account"
    
    // MARK: - Other
    
    static let utmSource = "app-ios"

    static let appStoreUrl = "itms-apps://itunes.apple.com/app/id1437005085"
    
}
