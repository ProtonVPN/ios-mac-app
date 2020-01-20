//
//  MapHeaderViewModel.swift
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

class MapHeaderViewModel {
    
    private let vpnGateway: VpnGatewayProtocol
    
    var contentChanged: (() -> Void)?
    
    init(vpnGateway: VpnGatewayProtocol) {
        self.vpnGateway = vpnGateway
        
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    var isConnected: Bool {
        return vpnGateway.connection == .connected
    }
    
    var description: NSAttributedString {
        let text = (isConnected ? LocalizedString.connected : LocalizedString.disconnected).uppercased()
        let color: NSColor = isConnected ? .protonGreen() : .protonRed()
        return text.attributed(withColor: color, fontSize: 19, bold: true)
    }
    
    var isSecureCore: Bool {
        if let server = vpnGateway.activeServer {
            return server.isSecureCore
        }
        return false
    }
    
    @objc private func vpnConnectionChanged() {
        contentChanged?()
    }
}
