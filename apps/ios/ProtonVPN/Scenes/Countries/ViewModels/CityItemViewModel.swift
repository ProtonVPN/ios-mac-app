//
//  Created on 16.03.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import UIKit

import ProtonCoreUIFoundations

import LegacyCommon
import VPNAppCore

import Domain
import Localization
import Search
import Strings
import Theme

final class CityItemViewModel: CityViewModel {
    private let alertService: AlertService
    private var vpnGateway: VpnGatewayProtocol
    private let connectionStatusService: ConnectionStatusService

    let cityName: String

    let translatedCityName: String?

    var countryName: String {
        LocalizationUtility.default.countryName(forCode: countryCode) ?? ""
    }

    var countryFlag: UIImage? {
        UIImage.flag(countryCode: countryCode)
    }

    var isUsersTierTooLow: Bool {
        servers.allSatisfy(\.isUsersTierTooLow)
    }

    var underMaintenance: Bool {
        servers.allSatisfy(\.underMaintenance)
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

    var isConnected: Bool {
        servers.contains(where: \.isConnected)
    }

    var isConnecting: Bool {
        servers.contains(where: \.isConnecting)
    }

    var isCurrentlyConnected: Bool {
        isConnected || isConnecting
    }

    var connectButtonColor: UIColor {
        if isUsersTierTooLow {
            return .clear
        }
        if underMaintenance {
            return .clear
        }
        return isCurrentlyConnected ? UIColor.interactionNorm() : UIColor.weakInteractionColor()
    }

    var connectionChanged: (() -> Void)?

    var textColor: UIColor {
        UIColor.normalTextColor()
    }

    private let servers: [ServerItemViewModel]
    private let countryCode: String

    init(
        cityName: String,
        translatedCityName: String?,
        countryCode: String,
        servers: [ServerItemViewModel],
        alertService: AlertService,
        vpnGateway: VpnGatewayProtocol,
        connectionStatusService: ConnectionStatusService
    ) {
        self.cityName = cityName
        self.translatedCityName = translatedCityName
        self.countryCode = countryCode
        self.servers = servers
        self.alertService = alertService
        self.vpnGateway = vpnGateway
        self.connectionStatusService = connectionStatusService

        AppEvent.connectionStateChanged.subscribe(self, selector: #selector(stateChanged))
    }

    func connectAction() {
        log.debug("Connect requested by clicking on Country item", category: .connectionConnect, event: .trigger)

        if isUsersTierTooLow {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            alertService.push(alert: AllCountriesUpsellAlert())
        } else if underMaintenance {
            log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
            alertService.push(alert: MaintenanceAlert(cityName: countryName))
        } else if isConnected {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.disconnect(.countriesCity))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else if isConnecting {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect)
            log.debug("Will connect to city: \(cityName) in country: \(countryName)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(country: countryCode, city: cityName)
            connectionStatusService.presentStatusViewController()
        }
    }

    // MARK: - Private functions

    @objc
    private func stateChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionChanged?()
        }
    }
}
