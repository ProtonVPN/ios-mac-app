//
//  Created on 2/8/22.
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

#if os(macOS)
import AppKit
public typealias Image = NSImage
#elseif os(iOS) || os(tvOS) || os(watchOS)
import UIKit
public typealias Image = UIImage
#endif

public enum Feature {
    case streaming
    case multipleDevices(Int)
    case netshield
    case highSpeed
    case blockAds
    case protectFromMalware
    case highSpeedNetshield
    case routeSecureServers
    case addLayer
    case protectFromAttacks
    case privacyFirst
    case activityLogging
    case noThirdParties
    case externalAudit
}

extension Feature {
    // swiftlint:disable:next cyclomatic_complexity
    public func title() -> String {
        switch self {
        case .streaming:
            return LocalizedString.modalsUpsellAllCountriesFeatureStreaming
        case .multipleDevices(let numberOfDevices):
            return LocalizedString.modalsUpsellAllCountriesFeatureMultipleDevices(numberOfDevices)
        case .netshield:
            return LocalizedString.modalsUpsellAllCountriesFeatureNetshield
        case .highSpeed:
            return LocalizedString.modalsUpsellAllCountriesFeatureHighSpeed
        case .blockAds:
            return LocalizedString.modalsUpsellNetShieldAds
        case .protectFromMalware:
            return LocalizedString.modalsUpsellNetShieldMalware
        case .highSpeedNetshield:
            return LocalizedString.modalsUpsellNetShieldHighSpeed
        case .routeSecureServers:
            return LocalizedString.modalsUpsellSecureCoreRoute
        case .addLayer:
            return LocalizedString.modalsUpsellSecureCoreLayer
        case .protectFromAttacks:
            return LocalizedString.modalsUpsellSecureCoreAttacks
        case .privacyFirst:
            return LocalizedString.modalsNoLogsPrivacyFirst
        case .activityLogging:
            return LocalizedString.modalsNoLogsLogActivity
        case .noThirdParties:
            return LocalizedString.modalsNoLogsThirdParties
        case .externalAudit:
            return LocalizedString.modalsNoLogsExternalAudit
        }
    }

    public var linkImage: Image? {
        switch self {
        case .externalAudit:
            return Asset.icArrowOutSquare.image
        default:
            return nil
        }
    }

    public var image: Image {
        switch self {
        case .streaming:
            return Asset.streamingIcon.image
        case .multipleDevices:
            return Asset.multipleDevicesIcon.image
        case .netshield:
            return Asset.netshieldIcon.image
        case .highSpeed:
            return Asset.highSpeedIcon.image
        case .blockAds:
            return Asset.blockAds.image
        case .protectFromMalware:
            return Asset.netshieldIcon.image
        case .highSpeedNetshield:
            return Asset.highSpeedIcon.image
        case .routeSecureServers:
            return Asset.routeSecureServers.image
        case .addLayer:
            return Asset.addLayer.image
        case .protectFromAttacks:
            return Asset.protectFromAttacks.image
        case .privacyFirst, .activityLogging, .noThirdParties:
            return Asset.checkmarkCircle.image
        case .externalAudit:
            return Asset.icLightbulb.image
        }
    }
}
