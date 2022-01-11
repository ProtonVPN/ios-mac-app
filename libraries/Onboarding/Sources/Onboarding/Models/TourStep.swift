//
//  Created on 03.01.2022.
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

import Foundation
import UIKit

enum TourStep: CaseIterable {
    case beProtected
    case unblockStreaming
    case netshield
}

extension TourStep {
    var image: UIImage {
        switch self {
        case .beProtected:
            return UIImage(named: "BeProtected", in: Bundle.module, compatibleWith: nil)!
        case .unblockStreaming:
            return UIImage(named: "UnblockStreaming", in: Bundle.module, compatibleWith: nil)!
        case .netshield:
            return UIImage(named: "Netshield", in: Bundle.module, compatibleWith: nil)!
        }
    }

    var title: String {
        switch self {
        case .beProtected:
            return LocalizedString.onboardingBeprotectedTitle
        case .unblockStreaming:
            return LocalizedString.onboardingUnblockstreamingTitle
        case .netshield:
            return LocalizedString.onboardingNetshieldTitle
        }
    }

    var subtitle: String {
        switch self {
        case .beProtected:
            return LocalizedString.onboardingBeprotectedSubtitle
        case .unblockStreaming:
            return LocalizedString.onboardingUnblockstreamingSubtitle
        case .netshield:
            return LocalizedString.onboardingNetshieldSubtitle
        }
    }

    var requiresPlus: Bool {
        return self != .beProtected
    }
}
