//
//  InfoViewModel.swift
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

import Foundation
import Cocoa
import vpncore

struct ServerInfoViewModel {
    
    private let serverModel: ServerModel
    
    var name: NSAttributedString {
        return "\(serverModel.country) \(serverModel.name)".attributed(withColor: NSColor.protonWhite(), fontSize: 13, alignment: .left)
    }
    
    let loadLabel = LocalizedString.serverLoad.attributed(withColor: NSColor.protonGreyButtonBackground(), fontSize: 12, alignment: .left)
    var load: NSAttributedString {
        return "\(serverModel.load)%".attributed(withColor: NSColor.protonWhite(), fontSize: 12, alignment: .left)
    }
    var loadValue: Int {
        return serverModel.load
    }
    
    let ipLabel = LocalizedString.serverIp.attributed(withColor: NSColor.protonGreyButtonBackground(), fontSize: 12, alignment: .left)
    var ip: String {
        if serverModel.isFree || serverModel.isSecureCore {
            return LocalizedString.autoAssigned
        } else {
            return serverModel.ips[0].exitIp
        }
    }
    
    var secureCoreLabel: NSAttributedString {
        let label = NSMutableAttributedString(string: LocalizedString.secureCore)
        availableAttributes(for: label)
        
        if !serverModel.isSecureCore {
            unavailableAttributes(for: label)
        }
        
        return label
    }
    
    var secureCoreImage: NSImage {
        if serverModel.isSecureCore {
            return #imageLiteral(resourceName: "protonvpn-server-sc-available")
        } else {
            return #imageLiteral(resourceName: "protonvpn-server-sc-unavailable")
        }
    }
    
    var p2pLabel: NSAttributedString {
        let label = NSMutableAttributedString(string: LocalizedString.p2pServer)
        availableAttributes(for: label)
        
        if !serverModel.supportsP2P {
            unavailableAttributes(for: label)
        }
        
        return label
    }
    
    var p2pImage: NSImage {
        if serverModel.supportsP2P {
            return #imageLiteral(resourceName: "protonvpn-server-p2p-available")
        } else {
            return #imageLiteral(resourceName: "protonvpn-server-p2p-unavailable")
        }
    }
    
    var premiumLabel: NSAttributedString {
        let label = NSMutableAttributedString(string: LocalizedString.premiumServer)
        availableAttributes(for: label)
        
        if serverModel.tier < 2 {
            unavailableAttributes(for: label)
        }
        
        return label
    }
    
    var premiumImage: NSImage {
        if serverModel.tier >= 2 {
            return #imageLiteral(resourceName: "protonvpn-server-premium-available")
        } else {
            return #imageLiteral(resourceName: "protonvpn-server-premium-unavailable")
        }
    }
    
    var torLabel: NSAttributedString {
        let label = NSMutableAttributedString(string: LocalizedString.torServer)
        availableAttributes(for: label)
        
        if !serverModel.supportsTor {
            unavailableAttributes(for: label)
        }
        
        return label
    }
    
    var torImage: NSImage {
        if serverModel.supportsTor {
            return #imageLiteral(resourceName: "protonvpn-server-tor-available")
        } else {
            return #imageLiteral(resourceName: "protonvpn-server-tor-unavailable")
        }
    }
    
    init(server: ServerModel) {
        serverModel = server
    }
    
    private func availableAttributes(for label: NSMutableAttributedString) {
        let range = (label.string as NSString).range(of: label.string)
        label.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: range)
        label.addAttribute(.foregroundColor, value: NSColor.protonGreen(), range: range)
    }
    
    private func unavailableAttributes(for label: NSMutableAttributedString) {
        let range = (label.string as NSString).range(of: label.string)
        label.addAttribute(.strikethroughStyle, value: true, range: range)
        label.addAttribute(.foregroundColor, value: NSColor.protonUnavailableGrey(), range: range)
    }
}
