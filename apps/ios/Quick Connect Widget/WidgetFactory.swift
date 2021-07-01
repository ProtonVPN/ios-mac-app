//
//  WidgetFactory.swift
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

import Foundation
import vpncore

final class WidgetFactory {
    private let openVpnExtensionBundleIdentifier = "ch.protonmail.vpn.OpenVPN-Extension"
    private let wireguardVpnExtensionBundleIdentifier = "ch.protonmail.vpn.WireGuardiOS-Extension"
    private let appGroup = AppConstants.AppGroups.main

    private let alertService = ExtensionAlertService()
    private let propertiesManager = PropertiesManager()
    
    init() {
        setUpNSCoding(withModuleName: "ProtonVPN")
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: appGroup)!)
    }

    func makeTodayViewModel() -> TodayViewModel {
        let openVpnFactory = OpenVpnProtocolFactory(bundleId: openVpnExtensionBundleIdentifier, appGroup: appGroup, propertiesManager: propertiesManager)
        let wireguardVpnFactory = WireguardProtocolFactory(bundleId: wireguardVpnExtensionBundleIdentifier, appGroup: appGroup, propertiesManager: propertiesManager)
        let vpnStateConfiguration = VpnStateConfigurationManager(ikeProtocolFactory: IkeProtocolFactory(), openVpnProtocolFactory: openVpnFactory, wireguardProtocolFactory: wireguardVpnFactory, propertiesManager: propertiesManager, appGroup: appGroup)
        let viewModel = TodayViewModel(vpnStateConfiguration: vpnStateConfiguration)
        alertService.delegate = viewModel
        return viewModel
    }
}
