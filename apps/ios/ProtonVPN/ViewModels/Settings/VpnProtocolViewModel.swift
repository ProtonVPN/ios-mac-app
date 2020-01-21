//
//  VpnProtocolViewModel.swift
//  ProtonVPN - Created on 12.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import vpncore

class VpnProtocolViewModel {
    
    var protocolChanged: ((VpnProtocol) -> Void)?
    var contentChanged: (() -> Void)?
    
    private var vpnProtocol: VpnProtocol
    private var openVpnTransportProtocol: VpnProtocol.TransportProtocol // maintains transport protocol selection even when vpn protocol is changed
    
    init(vpnProtocol: VpnProtocol) {
        self.vpnProtocol = vpnProtocol
        
        if case VpnProtocol.openVpn(let transportProtocol) = vpnProtocol {
            self.openVpnTransportProtocol = transportProtocol
        } else {
            self.openVpnTransportProtocol = .tcp
        }
    }
    
    var tableViewData: [TableViewSection] {
        var sections = [TableViewSection]()
        sections.append(vpnProtocols)
        
        if case VpnProtocol.openVpn = vpnProtocol {
            sections.append(transportProtocols)
        }
        
        return sections
    }
    
    private var vpnProtocols: TableViewSection {
        return TableViewSection(title: "", cells: [
            .checkmarkStandard(title: LocalizedString.ikev2, checked: vpnProtocol.isIke, handler: { [switchVpnProtocol] in
                switchVpnProtocol(.ike)
            }),
            .checkmarkStandard(title: LocalizedString.openVpn, checked: vpnProtocol.isOpenVpn, handler: { [openVpnTransportProtocol, switchVpnProtocol] in
                switchVpnProtocol(.openVpn(openVpnTransportProtocol))
            })
        ])
    }
    
    private var transportProtocols: TableViewSection {
        return TableViewSection(title: "", cells: [
            .checkmarkStandard(title: LocalizedString.tcp, checked: openVpnTransportProtocol == .tcp || openVpnTransportProtocol == .undefined, handler: { [switchTransportProtocol] in
                switchTransportProtocol(.tcp)
            }),
            .checkmarkStandard(title: LocalizedString.udp, checked: openVpnTransportProtocol == .udp, handler: { [switchTransportProtocol] in
                switchTransportProtocol(.udp)
            })
        ])
    }
    
    private func switchVpnProtocol(_ proto: VpnProtocol) {
        vpnProtocol = proto
        
        stateUpdated()
    }
    
    private func switchTransportProtocol(_ proto: VpnProtocol.TransportProtocol) {
        if case VpnProtocol.openVpn = vpnProtocol { // don't overwrite the vpn protocol
            vpnProtocol = .openVpn(proto)
        }
        
        openVpnTransportProtocol = proto
        
        stateUpdated()
    }
    
    private func stateUpdated() {
        protocolChanged?(vpnProtocol)
        contentChanged?()
    }
    
}
