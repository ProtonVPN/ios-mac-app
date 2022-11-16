//
//  FeatureCellViewModel.swift
//  vpncore - Created on 21.04.21.
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
import ProtonCore_UIFoundations
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public protocol FeatureCellViewModel {
    var icon: Image { get }
    var title: String { get }
    var sectionTitle: String? { get }
    var description: String { get }
    var footer: String { get }
    var urlContact: String { get }
    var displayLoads: Bool { get }
}

extension FeatureCellViewModel {
    public var displayLoads: Bool {
        return false
    }
}

// MARK: - Features

public struct SmartRoutingFeature: FeatureCellViewModel {
    public let icon: Image = IconProvider.globe
    public let title: String = LocalizedString.smartRoutingTitle
    public var sectionTitle: String?
    public let description: String = LocalizedString.featureSmartRoutingDescription
    public let footer: String = LocalizedString.learnMore
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreSmartRouting
    public init () { }
}

public struct StreamingFeature: FeatureCellViewModel {
    public let icon: Image = IconProvider.play
    public let title: String = LocalizedString.streamingTitle
    public var sectionTitle: String?
    public let description: String = LocalizedString.featureStreamingDescription
    public let footer: String = LocalizedString.learnMore
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreStreaming
    public init () { }
}

public struct P2PFeature: FeatureCellViewModel {
    public let icon: Image = IconProvider.arrowsSwitch
    public let title: String = LocalizedString.p2pTitle
    public var sectionTitle: String?
    public let description: String = LocalizedString.featureP2pDescription
    public let footer: String = LocalizedString.learnMore
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreP2p
    public init () { }
}

public struct TorFeature: FeatureCellViewModel {
    public let icon: Image = IconProvider.brandTor
    public let title: String = LocalizedString.featureTor
    public var sectionTitle: String?
    public let description: String = LocalizedString.featureTorDescription
    public let footer: String = LocalizedString.learnMore
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreTor
    public init () { }
}

public struct LoadPerformanceFeature: FeatureCellViewModel {
    public let icon: Image = IconProvider.servers
    public let title: String = LocalizedString.serverLoadTitle
    public var sectionTitle: String?
    public let description: String = LocalizedString.performanceLoadDescription
    public let footer: String = LocalizedString.learnMore
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreLoads
    public let displayLoads: Bool = true
    public init () { }
}

public struct FreeServersFeature: FeatureCellViewModel {
    public let icon: Image = IconProvider.servers
    public let title: String = LocalizedString.featureFreeServers
    public var sectionTitle: String?
    public let description: String = LocalizedString.featureFreeServersDescription
    public let footer: String = LocalizedString.learnMore
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreFreeServers
    public init () { }
}

public struct PartnersFeature: FeatureCellViewModel {
    #if os(macOS)
    public let icon: Image = Bundle.vpnCore.image(forResource: NSImage.Name("Deutsche-Welle-medium"))!
    #elseif os(iOS)
    public let icon: Image = UIImage(named: "Deutsche-Welle-medium", in: Bundle.vpnCore, with: nil)!
    #endif
    public let title: String = LocalizedString.featureDeutscheWelle
    public var sectionTitle: String? = LocalizedString.partnersTitle
    public let description: String = LocalizedString.featureDeutscheWelleDescription
    public let footer: String = LocalizedString.partnersFooter
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreDW
    public init () { }
}
