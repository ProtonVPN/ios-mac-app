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

        var availableProtocols: [VpnProtocol] = [
            .wireGuard(.udp),
            .openVpn(.udp),
            .openVpn(.tcp),
            .ike,
        ]

        let wireGuardTlsEnabled = featureFlags.wireGuardTls ||
            (connectionProtocol == .vpnProtocol(.wireGuard(.tcp)) ||
             connectionProtocol == .vpnProtocol(.wireGuard(.tls)))

        if wireGuardTlsEnabled {
            availableProtocols.append(contentsOf: [
                .wireGuard(.tcp),
                .wireGuard(.tls)
            ])
        }

        let availableProtocolsAndTitles = availableProtocols.map {
            (vpnProtocol: $0, title: $0.localizedString)
        }.sorted { lhs, rhs in
            lhs.title < rhs.title
        }

        availableProtocolsAndTitles.forEach { addProtocol in
            let (thisProtocol, title) = addProtocol
            cells.append(.checkmarkStandard(title: title,
                                            checked: vpnProtocol == thisProtocol && smartDisabled,
                                            handler: {
                self.switchConnectionProtocol(.vpnProtocol(thisProtocol))
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
