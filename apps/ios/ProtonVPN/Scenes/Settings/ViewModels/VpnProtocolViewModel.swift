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

        [VpnProtocol.wireGuard(.udp), VpnProtocol.openVpn(.udp), VpnProtocol.openVpn(.tcp), VpnProtocol.ike, VpnProtocol.wireGuard(.tcp), VpnProtocol.wireGuard(.tls)].forEach { addProtocol in
            cells.append(.checkmarkStandard(title: addProtocol.localizedString, checked: vpnProtocol == addProtocol && smartDisabled, handler: {
                self.switchConnectionProtocol(.vpnProtocol(addProtocol))
                return true
            }))
        }
        
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
