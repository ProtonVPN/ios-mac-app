//
//  Created on 10/11/2022.
//
//  Copyright (c) 2022 Proton AG
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

import ProtonCore_Networking
#if canImport(UIKit)
import UIKit
#endif

final class VPNPartnersRequest: Request {

    var path: String {
#if os(iOS)
        return "/vpn/v1/partners?WithImageScale=\(Int(UIScreen.main.scale))"
#else
        // For mac the backing scale factor always seem to return 2, so instead of
        // importing AppKit here and checking we'll just hard-code it.
        return "/vpn/v1/partners?WithImageScale=2"
#endif
    }

    var isAuth: Bool {
        return true
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .userInitiated // change to .background once production implements the endpoint
    }
}
