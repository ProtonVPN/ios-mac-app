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

    func push(alert: SystemAlert) {
    }
    
}

class WidgetFactory {
    
    static var shared = WidgetFactory()
    
    private let alamofireWrapper: AlamofireWrapper
    private let vpnApiService: VpnApiService
    private let vpnManager: VpnManager
    private let vpnKeychain: VpnKeychainProtocol
    private let configurationPreparer: VpnManagerConfigurationPreparer
    
    private var _vpnGateway: VpnGatewayProtocol?
    var vpnGateway: VpnGatewayProtocol? {
        guard let _ = try? vpnKeychain.fetch() else {
            _vpnGateway = nil
            return nil
        }
        
        if _vpnGateway == nil {
            _vpnGateway = VpnGateway(vpnApiService: vpnApiService, appStateManager: appStateManager, alertService: alertService, vpnKeychain: vpnKeychain, siriHelper: SiriHelper())
        }
        
        return _vpnGateway
    }
    
    let alertService = ExtensionAlertService()
    
    let propertiesManager = PropertiesManager()
    
    lazy var appStateManager = { [unowned self] in
        return AppStateManager(vpnApiService: vpnApiService, vpnManager: vpnManager, alamofireWrapper: alamofireWrapper, alertService: alertService, timerFactory: TimerFactory(), propertiesManager: propertiesManager, vpnKeychain: vpnKeychain, configurationPreparer: configurationPreparer)
    }()
    
    var todayViewModel:TodayViewModel {
        let viewModel = TodayViewModelImplementation( self )
        self.alertService.delegate = viewModel
        return viewModel
    }
    
    private init() {
        setUpNSCoding(withModuleName: "ProtonVPN")
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: "group.ch.protonmail.vpn")!)
        
        alamofireWrapper = AlamofireWrapperImplementation()
        vpnApiService = VpnApiService(alamofireWrapper: alamofireWrapper)
        let openVpnExtensionBundleIdentifier = "ch.protonmail.vpn.OpenVPN-Extension"
        let appGroup = "group.ch.protonmail.vpn"
        vpnManager = VpnManager(ikeFactory: IkeProtocolFactory(), openVpnFactory: OpenVpnProtocolFactory(bundleId: openVpnExtensionBundleIdentifier, appGroup: appGroup, propertiesManager: propertiesManager), appGroup: appGroup)
        vpnKeychain = VpnKeychain()
        configurationPreparer = VpnManagerConfigurationPreparer(vpnKeychain: vpnKeychain, alertService: alertService)
    }
    
    public func refreshVpnManager() {
        vpnManager.refreshManagers()
    }
}
