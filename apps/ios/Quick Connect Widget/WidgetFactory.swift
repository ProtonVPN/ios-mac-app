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

class AlertServiceStub: CoreAlertService {
    func push(alert: SystemAlert) { }
}

class WidgetFactory {
    
    static var shared = WidgetFactory()
    
    private let openVpnExtensionBundleIdentifier = "ch.protonmail.vpn.OpenVPN-Extension"
    private let appGroup = "group.ch.protonmail.vpn"

    let alertService = ExtensionAlertService()
    let propertiesManager = PropertiesManager()
    let alamofireWrapper = AlamofireWrapperImplementation()
    let vpnAuthenticationKeychain = VpnAuthenticationKeychain()

    var todayViewModel:TodayViewModel {
        let viewModel = TodayViewModelImplementation( self.propertiesManager, vpnManager: self.vpnManager, appStateManager: self.appStateManager )
        self.alertService.delegate = viewModel
        return viewModel
    }
    
    private init() {
        setUpNSCoding(withModuleName: "ProtonVPN")
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: self.appGroup)!)
    }
    
    
    // MARK: - Computed
    
    var vpnManager: VpnManagerProtocol {
        let openVpnFactory = OpenVpnProtocolFactory(bundleId: self.openVpnExtensionBundleIdentifier,
                                                    appGroup: self.appGroup,
                                                    propertiesManager: self.propertiesManager)
        return VpnManager(ikeFactory: IkeProtocolFactory(),
                          openVpnFactory: openVpnFactory,
                          appGroup: self.appGroup, vpnAuthentication: VpnAuthenticationManager(alamofireWrapper: alamofireWrapper, storage: vpnAuthenticationKeychain))
    }
    
    var appStateManager: AppStateManager {
        let keychain = VpnKeychain()
        return AppStateManagerImplementation(vpnApiService: VpnApiService(alamofireWrapper: alamofireWrapper),
                               vpnManager: self.vpnManager,
                               alamofireWrapper: alamofireWrapper,
                               alertService: alertService,
                               timerFactory: TimerFactory(),
                               propertiesManager: self.propertiesManager,
                               vpnKeychain: keychain,
                               configurationPreparer: VpnManagerConfigurationPreparer(vpnKeychain: keychain, alertService: self.alertService, propertiesManager: self.propertiesManager), vpnAuthentication: VpnAuthenticationManager(alamofireWrapper: alamofireWrapper, storage: vpnAuthenticationKeychain))
    }
}
