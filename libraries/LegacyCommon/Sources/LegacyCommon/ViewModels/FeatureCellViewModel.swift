//
//  FeatureCellViewModel.swift
//  vpncore - Created on 21.04.21.
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
import ProtonCoreUIFoundations
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Strings

public protocol FeatureCellViewModel {
    var icon: Icon { get }
    var title: String { get }
    var sectionTitle: String? { get }
    var description: String { get }
    var footer: String? { get }
    var urlContact: String? { get }
    var displayLoads: Bool { get }
}

public enum Icon {
    case image(Image)
    case url(URL?)
}

extension FeatureCellViewModel {
    public var displayLoads: Bool {
        return false
    }
}

// MARK: - Features

public struct SmartRoutingFeatureCellViewModel: FeatureCellViewModel {
    public let icon: Icon = .image(IconProvider.globe)
    public let title: String = Localizable.smartRoutingTitle
    public var sectionTitle: String?
    public let description: String = Localizable.featureSmartRoutingDescription
    public let footer: String? = Localizable.learnMore
    public let urlContact: String? = CoreAppConstants.ProtonVpnLinks.learnMoreSmartRouting
    public init () { }
}

public struct StreamingFeatureCellViewModel: FeatureCellViewModel {
    public let icon: Icon = .image(IconProvider.play)
    public let title: String = Localizable.streamingTitle
    public var sectionTitle: String?
    public let description: String = Localizable.featureStreamingDescription
    public let footer: String? = Localizable.learnMore
    public let urlContact: String? = CoreAppConstants.ProtonVpnLinks.learnMoreStreaming
    public init () { }
}

public struct P2PFeatureCellViewModel: FeatureCellViewModel {
    public let icon: Icon = .image(IconProvider.arrowsSwitch)
    public let title: String = Localizable.p2pTitle
    public var sectionTitle: String?
    public let description: String = Localizable.featureP2pDescription
    public let footer: String? = Localizable.learnMore
    public let urlContact: String? = CoreAppConstants.ProtonVpnLinks.learnMoreP2p
    public init () { }
}

public struct TorFeatureCellViewModel: FeatureCellViewModel {
    public let icon: Icon = .image(IconProvider.brandTor)
    public let title: String = Localizable.featureTor
    public var sectionTitle: String?
    public let description: String = Localizable.featureTorDescription
    public let footer: String? = Localizable.learnMore
    public let urlContact: String? = CoreAppConstants.ProtonVpnLinks.learnMoreTor
    public init () { }
}

public struct LoadPerformanceFeatureCellViewModel: FeatureCellViewModel {
    public let icon: Icon = .image(IconProvider.servers)
    public let title: String = Localizable.serverLoadTitle
    public var sectionTitle: String?
    public let description: String = Localizable.performanceLoadDescription
    public let footer: String? = Localizable.learnMore
    public let urlContact: String? = CoreAppConstants.ProtonVpnLinks.learnMoreLoads
    public let displayLoads: Bool = true
    public init () { }
}

public struct FreeServersFeatureCellViewModel: FeatureCellViewModel {
    public let icon: Icon = .image(IconProvider.servers)
    public let title: String = Localizable.featureFreeServers
    public var sectionTitle: String?
    public let description: String = Localizable.featureFreeServersDescription
    public let footer: String? = nil
    public let urlContact: String? = nil
    public init () { }
}

public struct ServerFeatureViewModel: FeatureCellViewModel {
    public var icon: Icon
    public let title: String
    public var sectionTitle: String?
    public let description: String
    public let footer: String? = nil
    public let urlContact: String? = nil
    public init (sectionTitle: String? = nil, title: String, description: String, icon: Icon) {
        self.sectionTitle = sectionTitle
        self.title = title
        self.icon = icon
        self.description = description
    }
}

public struct GatewayFeatureCellViewModel: FeatureCellViewModel {
    public let icon: Icon = .image(IconProvider.globe)
    public let title: String = Localizable.gatewaysModalTitle
    public var sectionTitle: String?
    public let description: String = Localizable.gatewaysModalText
    public let footer: String? = nil
    public let urlContact: String? = "https://protonvpn.com/support/dedicated-ips/"
    public init () { }
}
