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

public protocol FeatureCellViewModel {
    var icon: String { get }
    var title: String { get }
    var description: String { get }
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
    public let icon: String = "ic_smart-routing"
    public let title: String = LocalizedString.smartRoutingTitle
    public let description: String = LocalizedString.featureSmartRoutingDescription
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreSmartRouting
    public init () { }
}

public struct StreamingFeature: FeatureCellViewModel {
    public let icon: String = "ic_streaming"
    public let title: String = LocalizedString.streamingTitle
    public let description: String = LocalizedString.featureStreamingDescription
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreStreaming
    public init () { }
}

public struct P2PFeature: FeatureCellViewModel {
    public let icon: String = "ic_p2p"
    public let title: String = LocalizedString.p2pTitle
    public let description: String = LocalizedString.featureP2pDescription
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreP2p
    public init () { }
}

public struct TorFeature: FeatureCellViewModel {
    public let icon: String = "ic_tor"
    public let title: String = LocalizedString.featureTor
    public let description: String = LocalizedString.featureTorDescription
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreTor
    public init () { }
}

public struct LoadPerformanceFeature: FeatureCellViewModel {
    public let icon: String = "ic_server_load"
    public let title: String = LocalizedString.serverLoadTitle
    public let description: String = LocalizedString.performanceLoadDescription
    public let urlContact: String = CoreAppConstants.ProtonVpnLinks.learnMoreLoads
    public let displayLoads: Bool = true
    public init () { }
}
