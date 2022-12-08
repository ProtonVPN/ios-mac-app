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

    enum ProtocolChangeSelectionError: String, Error {
        case userCancelled = "The user cancelled the operation."
    }

    typealias ProtocolChangeConfirmationCallback = (Result<Bool, ProtocolChangeSelectionError>) -> Void
    typealias ProtocolChangeConfirmation = (ConnectionProtocol, @escaping ProtocolChangeConfirmationCallback) -> Void
    typealias ProtocolChangeCallback = (ConnectionProtocol, Bool) -> Void

    var protocolChanged: ProtocolChangeCallback?
    var protocolChangeConfirmation: ProtocolChangeConfirmation?
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
                self.confirmNewConnectionProtocol(.smartProtocol)
                return true
            }))
        }
        
        let smartDisabled = !displaySmartProtocol || connectionProtocol != .smartProtocol || !featureFlags.smartReconnect

        var availableProtocols = VpnProtocol.allCases

        let wireGuardTlsEnabled = featureFlags.wireGuardTls ||
            (connectionProtocol == .vpnProtocol(.wireGuard(.tcp)) ||
             connectionProtocol == .vpnProtocol(.wireGuard(.tls)))

        if !wireGuardTlsEnabled {
            availableProtocols.removeAll {
                $0 == .wireGuard(.tcp) || $0 == .wireGuard(.tls)
            }
        }

        let protocolCells: [TableViewCellModel] = availableProtocols.map {
            (vpnProtocol: $0, title: $0.localizedString)
        }.sorted { lhs, rhs in
            VpnProtocol.uiOrder[lhs.vpnProtocol] < VpnProtocol.uiOrder[rhs.vpnProtocol]
        }.map { item in
            .checkmarkStandard(title: item.title,
                               checked: vpnProtocol == item.vpnProtocol && smartDisabled) {
                self.confirmNewConnectionProtocol(.vpnProtocol(item.vpnProtocol))
                return true
            }
        }

        cells.append(contentsOf: protocolCells)

        return TableViewSection(title: "", showHeader: false, cells: cells)
    }
    
    private func confirmNewConnectionProtocol(_ connectionProtocol: ConnectionProtocol) {
        guard let protocolChangeConfirmation = protocolChangeConfirmation else {
            switchConnectionProtocol(to: connectionProtocol, reconnect: true)
            return
        }

        contentChanged?()

        protocolChangeConfirmation(connectionProtocol) { [weak self] result in
            switch result {
            case let .success(shouldReconnect):
                self?.switchConnectionProtocol(to: connectionProtocol, reconnect: shouldReconnect)
            case let .failure(error):
                log.error("Not reconnecting with \(connectionProtocol): \(error.rawValue)")
            }
        }
    }

    private func switchConnectionProtocol(to connectionProtocol: ConnectionProtocol, reconnect: Bool) {
        if let vpnProtocol = connectionProtocol.vpnProtocol {
            self.vpnProtocol = vpnProtocol
        }

        self.connectionProtocol = connectionProtocol
        self.protocolChanged?(connectionProtocol, reconnect)
        self.contentChanged?()
        self.selectionFinished?()
    }
}
