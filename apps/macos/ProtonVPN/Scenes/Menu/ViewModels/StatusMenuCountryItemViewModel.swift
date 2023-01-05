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
import vpncore

class StatusMenuCountryItemViewModel {
    
    private let countryGroup: CountryGroup
    private let type: ServerType
    private let vpnGateway: VpnGatewayProtocol
    
    var flag: NSImage {
        return AppTheme.Icon.flag(countryCode: countryGroup.country.countryCode) ?? NSImage()
    }
    
    var description: NSAttributedString {
        return formDescription()
    }
    
    init(countryGroup: CountryGroup, type: ServerType, vpnGateway: VpnGatewayProtocol) {
        self.countryGroup = countryGroup
        self.type = type
        self.vpnGateway = vpnGateway
    }
    
    func connect() {
        log.debug("Connect requested by selecting a country in status menu. Will connect to country: \(countryGroup.country.countryCode) serverType: \(type)", category: .connectionConnect, event: .trigger)
        vpnGateway.connectTo(country: countryGroup.country.countryCode, ofType: type, trigger: .country)
    }
    
    // MARK: - Private
    private func formDescription() -> NSAttributedString {
        let label: NSAttributedString
        let font = NSFont.themeFont(literalSize: 11)

        if type == .secureCore {
            let secureCoreIcon = AppTheme.Icon.chevronsRight.asAttachment(style: [.interactive, .strong], size: .square(16), centeredVerticallyForFont: font)
            let code = (" " + countryGroup.country.countryCode).styled(font: font)
            label = NSAttributedString.concatenate(secureCoreIcon, code)
        } else {
            label = countryGroup.country.countryCode.styled(font: font)
        }
        return label
    }
}
