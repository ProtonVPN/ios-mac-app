//
//  Created on 17.01.2022.
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

public enum CoreApiFeature: String {
    case onboardingShowFirstConnection = "OnboardingShowFirstConnection"
}

final class CoreApiFeatureRequest: Request {
    let feature: CoreApiFeature

    init(feature: CoreApiFeature) {
        self.feature = feature
    }

    var path: String {
        return "/core/v4/features/\(feature.rawValue)"
    }

    var isAuth: Bool {
        return false
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}
