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
        return NSImage(named: NSImage.Name(countryGroup.0.countryCode.lowercased() + "-plain")) ?? NSImage()
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
        vpnGateway.connectTo(country: countryGroup.0.countryCode, ofType: type)
    }
    
    // MARK: - Private
    private func formDescription() -> NSAttributedString {
        let label: NSAttributedString
        if type == .secureCore {
            let secureCoreIcon = NSAttributedString.imageAttachment(named: "double-arrow-right-green", width: 9, height: 9)!
            let code = (" " + countryGroup.0.countryCode).attributed(withColor: .protonWhite(), fontSize: 11)
            label = NSAttributedString.concatenate(secureCoreIcon, code)
        } else {
            label = countryGroup.0.countryCode.attributed(withColor: .protonWhite(), fontSize: 11)
        }
        return label
    }
}
