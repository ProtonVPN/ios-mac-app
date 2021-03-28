//
//  TroubleshootItem.swift
//  vpncore - Created on 26.02.2021.
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

public protocol TroubleshootItem {
    var title: String { get }
    var description: NSAttributedString { get }
}

public protocol ActionableTroubleshootItem: TroubleshootItem {
    var isOn: Bool { get }

    func set(isOn: Bool)
}

public struct BasicTroubleshootItem: TroubleshootItem {
    public let title: String
    public let description: NSAttributedString
}

public final class AlternateRoutingTroubleshootItem: ActionableTroubleshootItem {
    public let title: String
    public let description: NSAttributedString
    public var isOn: Bool

    private let propertiesManager: PropertiesManagerProtocol

    init(propertiesManager: PropertiesManagerProtocol) {
        self.propertiesManager = propertiesManager

        title = LocalizedString.troubleshootItemTitleAlternative
        description = NSMutableAttributedString(string: LocalizedString.troubleshootItemDescriptionAlternative).add(link: LocalizedString.troubleshootItemLinkAlternative1, withUrl: CoreAppConstants.ProtonVpnLinks.alternativeRouting)
        isOn = propertiesManager.alternativeRouting
    }

    public func set(isOn: Bool) {
        self.isOn = isOn
        propertiesManager.alternativeRouting = isOn
    }
}
