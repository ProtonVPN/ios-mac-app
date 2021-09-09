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
    
    var protocolChanged: ((ConnectionProtocol) -> Void)?
    var contentChanged: (() -> Void)?
    
    private var vpnProtocol: VpnProtocol = .ike
    private var connectionProtocol: ConnectionProtocol
    private let featureFlags: FeatureFlags
    private let alertService: AlertService
    private let displaySmartProtocol: Bool
    
    init(connectionProtocol: ConnectionProtocol, displaySmartProtocol: Bool = true, featureFlags: FeatureFlags, alertService: AlertService) {
        self.connectionProtocol = connectionProtocol
        self.featureFlags = featureFlags
        self.alertService = alertService
        self.displaySmartProtocol = displaySmartProtocol
        if case ConnectionProtocol.vpnProtocol(let vpnProtocol) = connectionProtocol {
            self.vpnProtocol = vpnProtocol
        }
    }
    
    var tableViewData: [TableViewSection] {
        return [vpnProtocols]
    }
    
    private var vpnProtocols: TableViewSection {
        var cells = [TableViewCellModel]()
        
        if displaySmartProtocol {
            cells.append(.checkmarkStandard(title: LocalizedString.smartTitle, checked: connectionProtocol == .smartProtocol, handler: {
                self.switchConnectionProtocol(.smartProtocol)
                return true
            }))
        }
        
        let smartDisabled = !displaySmartProtocol || connectionProtocol != .smartProtocol || !featureFlags.smartReconnect
        
        cells.append(
            .checkmarkStandard(title: LocalizedString.wireguard, checked: vpnProtocol.isWireGuard && smartDisabled, handler: {
                self.switchConnectionProtocol(.vpnProtocol(.wireGuard))
                return true
            }))
        
        let isUDP = vpnProtocol.isOpenVpn(.udp)
        
        cells.append(.checkmarkStandard(title: VpnProtocol.openVpn(.udp).localizedString, checked: isUDP && smartDisabled, handler: {
            self.switchConnectionProtocol(.vpnProtocol(.openVpn(.udp)))
            return true
        }))
        
        let isTCP = vpnProtocol.isOpenVpn(.tcp)
        
        cells.append(.checkmarkStandard(title: VpnProtocol.openVpn(.tcp).localizedString, checked: isTCP && smartDisabled, handler: {
            self.switchConnectionProtocol(.vpnProtocol(.openVpn(.tcp)))
            return true
        }))
        
        cells.append(.checkmarkStandard(title: LocalizedString.ikev2, checked: vpnProtocol.isIke && smartDisabled, handler: {
            self.switchConnectionProtocol(.vpnProtocol(.ike))
            return true
        }))
        
        return TableViewSection(title: "", showHeader: false, cells: cells)
    }
    
    private func switchConnectionProtocol(_ connectionProtocol: ConnectionProtocol) {
        if case ConnectionProtocol.vpnProtocol(let proto) = connectionProtocol {
            self.vpnProtocol = proto
        }
        self.connectionProtocol = connectionProtocol
        stateUpdated()
    }
    
    private func stateUpdated() {
        protocolChanged?(connectionProtocol)
        contentChanged?()
    }
}
