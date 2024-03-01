//
//  StatusMenuCountryItemViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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

import Cocoa
import LegacyCommon
import Theme
import ProtonCoreUIFoundations

class StatusMenuCountryItemViewModel {
    
    private let serverGroup: ServerGroup
    private let type: ServerType
    private let vpnGateway: VpnGatewayProtocol
    
    var flag: NSImage {
        switch serverGroup.kind {
        case .country(let country):
            return AppTheme.Icon.flag(countryCode: country.countryCode) ?? NSImage()
        case .gateway:
            return IconProvider.servers
        }
    }
    
    var description: NSAttributedString {
        return formDescription()
    }
    
    init(countryGroup: ServerGroup, type: ServerType, vpnGateway: VpnGatewayProtocol) {
        self.serverGroup = countryGroup
        self.type = type
        self.vpnGateway = vpnGateway
    }
    
    func connect() {
        log.debug("Connect requested by selecting a country in status menu. Will connect to country: \(serverGroup) serverType: \(type)", category: .connectionConnect, event: .trigger)

        switch serverGroup.kind {
        case .country(let country):
            vpnGateway.connectTo(country: country.countryCode, ofType: type, trigger: .country)

        case .gateway:
            log.assertionFailure("Connect requested by selecting a gateway in status menu. This is not supported.", category: .connectionConnect, event: .trigger)
        }
    }
    
    // MARK: - Private
    private func formDescription() -> NSAttributedString {
        let label: NSAttributedString
        let font = NSFont.themeFont(literalSize: 11)

        let name: String
        switch serverGroup.kind {
        case .country(let country):
            name = country.countryCode
        case .gateway(let gatewayName):
            name = gatewayName
        }

        if type == .secureCore {
            let secureCoreIcon = AppTheme.Icon.chevronsRight.asAttachment(style: [.interactive, .strong], size: .square(16), centeredVerticallyForFont: font)
            let code = (" " + name).styled(font: font)
            label = NSAttributedString.concatenate(secureCoreIcon, code)
        } else {
            label = name.styled(font: font)
        }
        return label
    }
}
