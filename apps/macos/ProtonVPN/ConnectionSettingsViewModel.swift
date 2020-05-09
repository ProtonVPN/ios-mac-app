//
//  ConnectionSettingsViewModel.swift
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

class ConnectionSettingsViewModel {
    
    let propertiesManager = PropertiesManager()
    
    private let profileManager = ProfileManager.shared
    private let vpnGateway: VpnGatewayProtocol
    private let firewallManager: FirewallManager
    
    var killSwitchWarning: ((WarningPopupViewModel) -> Void)?
    let killSwitchChanged = Notification.Name("SettingsViewModelKillSwitchChanged") // two observers
    
    init(vpnGateway: VpnGatewayProtocol, firewallManager: FirewallManager) {
        self.vpnGateway = vpnGateway
        self.firewallManager = firewallManager
    }
    
    // MARK: - Current Index
    
    var autoConnectProfileIndex: Int {
        let autoConnect = propertiesManager.autoConnect
        
        if autoConnect.enabled {
            guard let profileId = autoConnect.profileId else { return 1 }
            let index = profileManager.allProfiles.index {
                $0.id == profileId
            }
            
            guard let profileIndex = index else { return 1 }
            let listIndex = profileIndex + 1
            guard listIndex < autoConnectItemCount else { return 1 }
            return listIndex
        } else {
            return 0
        }
    }
    
    var quickConnectProfileIndex: Int {
        guard let profileId = propertiesManager.quickConnect else { return 0 }
        let index = profileManager.allProfiles.index {
            $0.id == profileId
        }
        
        guard let profileIndex = index, profileIndex < quickConnectItemCount else { return 0 }
        return profileIndex
    }
    
    var protocolProfileIndex: Int {
        switch vpnProtocol {
        case .ike:
            return 0
        default:
            return 1
        }
    }
    
    var openVPNProfileIndex: Int {
        switch vpnProtocol {
        case .openVpn(.udp):
            return 1
        default:
            return 0
        }
    }
    
    // MARK: - Item counts
    
    var autoConnectItemCount: Int {
        return profileManager.allProfiles.count + 1
    }
    
    var quickConnectItemCount: Int {
        return profileManager.allProfiles.count
    }
    
    var protocolItemCount: Int { return 2 }
    
    var openVPNItemCount: Int { return 2 }
        
    // MARK: - Setters
    
    func setAutoConnect(_ index: Int) throws {
        guard index < autoConnectItemCount else {
            throw NSError()
        }
        
        if index > 0 {
            let selectedProfile = profileManager.allProfiles[index - 1]
            propertiesManager.autoConnect = (enabled: true, profileId: selectedProfile.id)
        } else {
            propertiesManager.autoConnect = (enabled: false, profileId: nil)
        }
    }
    
    func setQuickConnect(_ index: Int) throws {
        guard index < quickConnectItemCount else {
            throw NSError()
        }
        
        let selectedProfile = profileManager.allProfiles[index]
        propertiesManager.quickConnect = selectedProfile.id
    }
    
    func setProtocol(_ index: Int) {
        if index == 0 {
            propertiesManager.vpnProtocol = .ike
        } else {
            propertiesManager.vpnProtocol = .openVpn(.tcp)
        }
    }
    
    func setOpenVPN(_ index: Int) {
        if index == 0 {
            propertiesManager.vpnProtocol = .openVpn(.tcp)
        } else {
            propertiesManager.vpnProtocol = .openVpn(.udp)
        }
    }
    
    // MARK: - Item
    
    func autoConnectItem(for index: Int) -> NSAttributedString {
        if index > 0 {
            return profileString(for: index - 1)
        } else {
            let imageAttributedString = attributedAttachment(for: .protonUnavailableGrey())
            return concatenated(imageString: imageAttributedString, with: LocalizedString.disabled)
        }
    }
    
    func quickConnectItem(for index: Int) -> NSAttributedString {
        return profileString(for: index)
    }
        
    func protocolItem(for index: Int) -> NSAttributedString {
        switch index {
        case 0:
            return LocalizedString.ikev2.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        default:
            return LocalizedString.openVpn.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        }
    }
        
    func openVPNItem(for index: Int) -> NSAttributedString {
        switch index {
        case 0:
            return LocalizedString.tcp.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        default:
            return LocalizedString.udp.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        }
    }
    
    // MARK: - Values
    
    var killSwitch: Bool {
        return propertiesManager.killSwitch
    }
    
    var vpnProtocol: VpnProtocol {
        return propertiesManager.vpnProtocol
    }
    
    func setKillSwitch(_ enabled: Bool) {
        propertiesManager.killSwitch = enabled
        
        if enabled {
            enableKillSwitch()
        } else {
            firewallManager.disableFirewall()
        }
    }
    
    private func enableKillSwitch() {
        firewallManager.installHelperIfNeeded(.userInitiated)
    }
    
    private func attributedAttachment(for color: NSColor, width: CGFloat = 12) -> NSAttributedString {
        let profileCircle = ProfileCircle(frame: CGRect(x: 0, y: 0, width: width, height: width))
        profileCircle.profileColor = color
        let data = profileCircle.dataWithPDF(inside: profileCircle.bounds)
        let image = NSImage(data: data)
        let attachmentCell = NSTextAttachmentCell(imageCell: image)
        let attachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell
        return NSAttributedString(attachment: attachment)
    }
    
    private func concatenated(imageString: NSAttributedString, with text: String) -> NSAttributedString {
        let nameAttributedString = ("  " + text).attributed(withColor: .protonWhite(), fontSize: 16)
        let attributedString = NSMutableAttributedString(attributedString: NSAttributedString.concatenate(imageString, nameAttributedString))
        let range = (attributedString.string as NSString).range(of: attributedString.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        attributedString.setAlignment(.left, range: range)
        return attributedString
    }
    
    private func profileString(for index: Int) -> NSAttributedString {
        let profile = profileManager.allProfiles[index]
        return concatenated(imageString: profile.profileIcon.attributedAttachment(), with: profile.name)
    }
}
