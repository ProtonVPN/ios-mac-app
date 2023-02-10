//
//  Created on 11.01.23.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation
import LocalFeatureFlags

public enum LogicalFeature: String, FeatureFlag {
    public var category: String {
        "Logicals"
    }

    case perProtocolEntries = "PerProtocolEntries"
}

public enum OpenVPNFeature: String, FeatureFlag {
    public var category: String {
        "OpenVPN"
    }

    // OpenVPN certificate based authentication. Remove in 2024.
    case iosCertificates = "IOS-Certificates"

    // OpenVPN certificate based authentication on macOS. Remove in 2024.
    case macCertificates = "Mac-Certificates"

}
