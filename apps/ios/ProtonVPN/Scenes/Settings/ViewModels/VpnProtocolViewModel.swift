//
//  VpnProtocolViewModel.swift
//  ProtonVPN - Created on 12.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation

import Domain
import LegacyCommon
import Localization
import VPNAppCore

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
    private var smartProtocolConfig: SmartProtocolConfig
    private let availableProtocols: [ConnectionProtocol]

    init(connectionProtocol: ConnectionProtocol,
         smartProtocolConfig: SmartProtocolConfig,
         supportedProtocols: [ConnectionProtocol] = ConnectionProtocol.allCases,
         displaySmartProtocol _: Bool = true,
         featureFlags: FeatureFlags) {
        self.selectedProtocol = connectionProtocol
        self.smartProtocolConfig = smartProtocolConfig

        let wireguardTLSProtocols = [.tcp, .udp].map { ConnectionProtocol.vpnProtocol(.wireGuard($0)) }
        self.availableProtocols = supportedProtocols
            .removing(wireguardTLSProtocols, if: !featureFlags.wireGuardTls)
            .filter { !$0.isDeprecated }
    }

    var tableViewData: [TableViewSection] {
        [vpnProtocolsTableSection]
    }

    private var vpnProtocolsTableSection: TableViewSection {
        let cells: [TableViewCellModel] = availableProtocols
            .sorted(by: ConnectionProtocol.uiSort)
            .map { item in
                let handler = { [unowned self] in
                    confirmNewConnectionProtocol(item)
                    return true
                }

                return .checkmarkStandard(title: item.localizedDescription,
                                          checked: selectedProtocol == item,
                                          handler: handler)
            }

        return TableViewSection(title: "", showHeader: false, cells: cells)
    }

    private func confirmNewConnectionProtocol(_ connectionProtocol: ConnectionProtocol) {
        guard let protocolChangeConfirmation else {
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
        selectedProtocol = connectionProtocol
        protocolChanged?(connectionProtocol, reconnect)
        contentChanged?()
        selectionFinished?()
    }
}
