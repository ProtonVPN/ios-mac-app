//
//  SiriHandlerViewModel.swift
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

@available(iOSApplicationExtension 12.0, *)
class SiriHandlerViewModel {
    
    private let alamofireWrapper: AlamofireWrapper
    private let vpnApiService: VpnApiService
    private let vpnManager: VpnManager
    private let vpnKeychain: VpnKeychainProtocol
    private let propertiesManager: PropertiesManagerProtocol
    private let configurationPreparer: VpnManagerConfigurationPreparer
    
    private let alertService = ExtensionAlertService()
    
    lazy var appStateManager = { [unowned self] in
        return AppStateManager(vpnApiService: vpnApiService, vpnManager: vpnManager, alamofireWrapper: alamofireWrapper, alertService: alertService, timerFactory: TimerFactory(), propertiesManager: propertiesManager, vpnKeychain: vpnKeychain, configurationPreparer: configurationPreparer)
        }()
    
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
    
    init(alamofireWrapper: AlamofireWrapper, vpnApiService: VpnApiService, vpnManager: VpnManager, vpnKeychain: VpnKeychainProtocol, propertiesManager: PropertiesManagerProtocol) {
        setUpNSCoding(withModuleName: "ProtonVPN")
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: "group.ch.protonmail.vpn")!)
        
        self.alamofireWrapper = alamofireWrapper
        self.vpnApiService = vpnApiService
        self.vpnManager = vpnManager
        self.vpnKeychain = vpnKeychain
        self.propertiesManager = propertiesManager
        self.configurationPreparer = VpnManagerConfigurationPreparer(vpnKeychain: vpnKeychain, alertService: alertService, propertiesManager: propertiesManager)
        
        self.alertService.delegate = self
    }
    
    public func connect(_ completion: @escaping (QuickConnectIntentResponse) -> Void) {
        guard let vpnGateway = vpnGateway else {
            // Not logged in so open the app
            completion(QuickConnectIntentResponse(code: .continueInApp, userActivity: nil))
            return
        }
        
        // Without refresh, from time to time it doesn't see newest default profile
        ProfileManager.shared.refreshProfiles()
        
        propertiesManager.lastConnectionRequest = vpnGateway.quickConnectConnectionRequest()
        
        let activity = NSUserActivity(activityType: "com.protonmail.vpn.connect")
        completion(QuickConnectIntentResponse(code: .continueInApp, userActivity: activity))
    }
    
    public func disconnect(_ completion: @escaping (DisconnectIntentResponse) -> Void) {
        guard vpnGateway != nil else {
            // Not logged in so open the app
            completion(DisconnectIntentResponse(code: .continueInApp, userActivity: nil))
            return
        }
        
        let activity = NSUserActivity(activityType: "com.protonmail.vpn.disconnect")
        completion(DisconnectIntentResponse(code: .continueInApp, userActivity: activity))
    }
    
    public func getConnectionStatus(_ completion: @escaping (GetConnectionStatusIntentResponse) -> Void) {
        let status = getConnectionStatusString(connection: vpnGateway?.connection)
        let response = GetConnectionStatusIntentResponse.success(status: status)

        completion(response)
    }

    private func getConnectionStatusString(connection: ConnectionStatus?) -> String {
        switch connection {
        case .connected:
            return LocalizedString.connected
        case .connecting:
            return LocalizedString.connecting
        case .disconnected:
            return LocalizedString.disconnected
        case .disconnecting:
            return LocalizedString.disconnecting
        default:
            return LocalizedString.vpnStatusNotLoggedIn
        }
    }
    
}

@available(iOSApplicationExtension 12.0, *)
extension SiriHandlerViewModel: ExtensionAlertServiceDelegate {
    
    func actionErrorReceived() {}
    
}
