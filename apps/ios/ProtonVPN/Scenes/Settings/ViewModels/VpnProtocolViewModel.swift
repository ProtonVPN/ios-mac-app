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

final class VpnProtocolViewModel {
    
    var protocolChanged: ((VpnProtocol) -> Void)?
    var contentChanged: (() -> Void)?
    
    private var vpnProtocol: VpnProtocol
    private var openVpnTransportProtocol: VpnProtocol.TransportProtocol // maintains transport protocol selection even when vpn protocol is changed
    private let featureFlags: FeatureFlags
    private let alertService: AlertService
    private let showProtocolWarnings: Bool
    
    init(vpnProtocol: VpnProtocol, featureFlags: FeatureFlags, alertService: AlertService, showProtocolWarnings: Bool = true) {
        self.vpnProtocol = vpnProtocol
        self.featureFlags = featureFlags
        self.alertService = alertService
        self.showProtocolWarnings = showProtocolWarnings
        
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
        var cells = [TableViewCellModel]()
            
        cells.append(.checkmarkStandard(title: LocalizedString.ikev2, checked: vpnProtocol.isIke, handler: { [switchVpnProtocol] in
            switchVpnProtocol(.ike)
            return true
        }))
        
        if featureFlags.isWireGuard {
            cells.append(
                .checkmarkStandard(title: LocalizedString.wireguard, checked: vpnProtocol.isWireGuard, handler: { [switchVpnProtocol, alertService, showProtocolWarnings] in
                    guard showProtocolWarnings else {
                        switchVpnProtocol(.wireGuard)
                        return true
                    }

                    let alert = WireguardSupportWarningAlert(continueHandler: { [switchVpnProtocol] in
                        switchVpnProtocol(.wireGuard)
                    })
                    alertService.push(alert: alert)
                    return false
            }))
        }
        
        cells.append(.checkmarkStandard(title: LocalizedString.openVpn, checked: vpnProtocol.isOpenVpn, handler: { [openVpnTransportProtocol, switchVpnProtocol] in
            switchVpnProtocol(.openVpn(openVpnTransportProtocol))
            return true
        }))
                
        return TableViewSection(title: "", cells: cells)
    }
    
    private var transportProtocols: TableViewSection {
        return TableViewSection(title: "", cells: [
            .checkmarkStandard(title: LocalizedString.tcp, checked: openVpnTransportProtocol == .tcp || openVpnTransportProtocol == .undefined, handler: { [switchTransportProtocol] in
                switchTransportProtocol(.tcp)
                return true
            }),
            .checkmarkStandard(title: LocalizedString.udp, checked: openVpnTransportProtocol == .udp, handler: { [switchTransportProtocol] in
                switchTransportProtocol(.udp)
                return true
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
