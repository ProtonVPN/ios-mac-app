//
//  ServerItemViewModel.swift
//  ProtonVPN - Created on 01.07.19.
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

import Combine
import UIKit

import AlamofireImage
import CommonNetworking
import ComposableArchitecture
import Dependencies
import LegacyCommon
import Localization
import Persistence
import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
import Search
import VPNAppCore

import Domain
import Strings
import Theme

class ServerItemViewModel: ServerItemViewModelCore {
    @Dependency(\.serverRepository) var repository

    private let alertService: AlertService
    private let connectionStatusService: ConnectionStatusService
    private let planService: PlanService

    var partnersIconsReceipts: [RequestReceipt] = []

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
    var isConnected: Bool {
        guard case let .connected(_, actual) = vpnConnectionStatus, actual?.server.logical.id == serverModel.logical.id else {
            return false
        }
        return true
    }

    var isConnecting: Bool {
        guard case let .connecting(_, server) = vpnConnectionStatus, server?.logical.id == serverModel.logical.id else {
            return false
        }

        return true
    }

    var viaCountry: (name: String, code: String)? {
        nil
    }

    var connectedUiState: Bool {
        isConnected || isConnecting
    }

    fileprivate var canConnect: Bool {
        !isUsersTierTooLow && !underMaintenance
    }

    var connectionChanged: (() -> Void)?
    var countryConnectionChanged: Notification.Name?

    // MARK: First line in the TableCell

    var description: String { serverModel.logical.name }

    var city: String {
        serverModel.logical.city ?? ""
    }

    var loadColor: UIColor {
        if serverModel.logical.load > 90 {
            .notificationErrorColor()
        } else if serverModel.logical.load > 75 {
            .notificationWarningColor()
        } else {
            .notificationOKColor()
        }
    }

    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            Theme.Asset.vpnSubscriptionBadge.image
        } else if underMaintenance {
            IconProvider.wrench
        } else {
            IconProvider.powerOff
        }
    }

    var textInPlaceOfConnectIcon: String? {
        isUsersTierTooLow ? Localizable.upgrade : nil
    }

    init(
        serverModel: ServerInfo,
        vpnGateway: VpnGatewayProtocol,
        appStateManager: AppStateManager,
        alertService: AlertService,
        connectionStatusService: ConnectionStatusService,
        planService: PlanService
    ) {
        self.alertService = alertService
        self.connectionStatusService = connectionStatusService
        self.planService = planService

        super.init(
            serverModel: serverModel,
            vpnGateway: vpnGateway,
            appStateManager: appStateManager
        )
        if canConnect {
            startObserving()
        }
    }

    func connectAction() {
        log.debug("Connect requested by clicking on Server item", category: .connectionConnect, event: .trigger)

        if underMaintenance {
            log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
            alertService.push(alert: MaintenanceAlert(forSpecificCountry: nil))
        } else if isUsersTierTooLow {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.usePaymentsV2) {
                Task {
                    @Dependency(\.planServiceV2) var planServiceV2
                    await planServiceV2.presentSubscriptionManagement(alertService: alertService)
                }
            } else {
                planService.presentSubscriptionManagement()
            }
        } else if isConnected {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.disconnect(.server))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else if isConnecting {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            guard let server = repository.getFirstServer(
                filteredBy: [.logicalID(serverModel.logical.id)],
                orderedBy: .fastest
            ) else {
                log.error("No server found with logical ID \(serverModel.logical.id)")
                return
            }
            let legacyModel = ServerModel(server: server)
            log.debug("Will connect to \(legacyModel.logDescription)", category: .connectionConnect, event: .trigger)
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect)
            vpnGateway.connectTo(server: legacyModel)
            connectionStatusService.presentStatusViewController()
        }
    }

    // MARK: - Private functions

    private var cancellables = Set<AnyCancellable>()

    fileprivate func startObserving() {
        $vpnConnectionStatus
            .publisher
            .sink { [weak self] _ in
                self?.stateChanged()
            }
            .store(in: &cancellables)
    }

    @objc
    fileprivate func stateChanged() {
        if let connectionChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
    }
}

// MARK: - SecureCoreServerItemViewModel subclass

class SecureCoreServerItemViewModel: ServerItemViewModel {
    override var viaCountry: (name: String, code: String)? {
        isSecureCoreEnabled ? (serverModel.logical.entryCountry, serverModel.logical.entryCountryCode) : nil
    }
}

// MARK: - Search

extension ServerItemViewModel: ServerViewModel {
    var connectButtonColor: UIColor {
        if isUsersTierTooLow {
            return .clear
        }
        if underMaintenance {
            return .clear
        }
        return connectedUiState ? UIColor.interactionNorm() : UIColor.weakInteractionColor()
    }

    var entryCountryName: String? {
        viaCountry?.name
    }

    var entryCountryFlag: UIImage? {
        guard let code = viaCountry?.code else {
            return nil
        }

        return UIImage.flag(countryCode: code)
    }

    var countryName: String {
        LocalizationUtility.default.countryName(forCode: serverModel.logical.exitCountryCode) ?? ""
    }

    var countryFlag: UIImage? {
        UIImage.flag(countryCode: serverModel.logical.exitCountryCode)
    }

    var translatedCity: String? {
        serverModel.logical.translatedCity
    }

    var textColor: UIColor {
        UIColor.normalTextColor()
    }
}
