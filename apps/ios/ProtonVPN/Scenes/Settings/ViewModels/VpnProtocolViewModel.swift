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
    var protocolChangeConfirmation: ((@escaping (Bool) -> Void) -> Void)?
    var contentChanged: (() -> Void)?
    var selectionFinished: (() -> Void)?
    
    private var vpnProtocol: VpnProtocol = .ike
    private var connectionProtocol: ConnectionProtocol
    private let featureFlags: FeatureFlags
    private let displaySmartProtocol: Bool
    
    init(connectionProtocol: ConnectionProtocol, displaySmartProtocol: Bool = true, featureFlags: FeatureFlags) {
        self.connectionProtocol = connectionProtocol
        self.featureFlags = featureFlags
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
        let update = {
            if case ConnectionProtocol.vpnProtocol(let proto) = connectionProtocol {
                self.vpnProtocol = proto
            }
            self.connectionProtocol = connectionProtocol
            self.stateUpdated()
            self.selectionFinished?()
        }

        guard let protocolChangeConfirmation = protocolChangeConfirmation else {
            update()
            return
        }

        contentChanged?()

        protocolChangeConfirmation { confirmed in
            guard confirmed else {
                return
            }

            update()
        }
    }
    
    private func stateUpdated() {
        protocolChanged?(connectionProtocol)
        contentChanged?()
    }
}
