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

    private var selectedProtocol: ConnectionProtocol
    private let featureFlags: FeatureFlags
    private let displaySmartProtocol: Bool

    init(connectionProtocol: ConnectionProtocol, displaySmartProtocol: Bool = true, featureFlags: FeatureFlags) {
        self.selectedProtocol = connectionProtocol
        self.featureFlags = featureFlags
        self.displaySmartProtocol = displaySmartProtocol
    }

    var tableViewData: [TableViewSection] {
        return [vpnProtocols]
    }

    private var availableConnectionProtocols: [ConnectionProtocol] {
        let wireGuardTlsProtocols: [ConnectionProtocol] = [.tcp, .tls].map { .vpnProtocol(.wireGuard($0)) }
        let wireGuardTlsEnabled = featureFlags.wireGuardTls || wireGuardTlsProtocols.contains(selectedProtocol)

        return ConnectionProtocol.allCases
            .removing(.smartProtocol, if: !displaySmartProtocol)
            .removing(wireGuardTlsProtocols, if: !wireGuardTlsEnabled)
    }

    private var vpnProtocols: TableViewSection {
        let protocolCells: [TableViewCellModel] = availableConnectionProtocols
            .sorted(by: ConnectionProtocol.uiOrder)
            .map { connectionProtocol in
                .checkmarkStandard(title: connectionProtocol.localizedString, checked: connectionProtocol == selectedProtocol) {
                    self.confirmNewConnectionProtocol(connectionProtocol)
                    return true
                }
            }

        return TableViewSection(title: "", showHeader: false, cells: protocolCells)
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
        self.selectedProtocol = connectionProtocol
        self.protocolChanged?(connectionProtocol, reconnect)
        self.contentChanged?()
        self.selectionFinished?()
    }
}
