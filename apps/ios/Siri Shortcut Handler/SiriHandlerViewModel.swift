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
import LegacyCommon
import Timer
import VPNShared
import Strings

class SiriHandlerViewModel {
    
    private let networking: Networking
    private let vpnApiService: VpnApiService
    private let vpnManager: VpnManager
    private let vpnKeychain: VpnKeychainProtocol
    private let authKeychain: AuthKeychainHandle
    private let propertiesManager: PropertiesManagerProtocol
    private let configurationPreparer: VpnManagerConfigurationPreparer
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private let natTypePropertyProvider: NATTypePropertyProvider
    private let safeModePropertyProvider: SafeModePropertyProvider
    private let profileManager: ProfileManager
    private let doh: DoHVPN
    private let sessionService: SessionService
    private let availabilityCheckerResolverFactory: AvailabilityCheckerResolverFactory
    
    private let alertService = ExtensionAlertService()
    
    lazy var appStateManager: AppStateManager = {
        let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
        let vpnAuthKeychain = VpnAuthenticationKeychain(accessGroup: "\(appIdentifierPrefix)prt.ProtonVPN",
                                                        vpnKeysGenerator: ExtensionVPNKeysGenerator())
        return AppStateManagerImplementation(
            vpnApiService: vpnApiService,
            vpnManager: vpnManager,
            networking: networking,
            alertService: alertService,
            timerFactory: TimerFactoryImplementation(),
            propertiesManager: propertiesManager,
            vpnKeychain: vpnKeychain,
            configurationPreparer: configurationPreparer,
            vpnAuthentication: VpnAuthenticationRemoteClient(
                sessionService: sessionService,
                authenticationStorage: vpnAuthKeychain
            ),
            doh: doh,
            natTypePropertyProvider: natTypePropertyProvider,
            netShieldPropertyProvider: netShieldPropertyProvider,
            safeModePropertyProvider: safeModePropertyProvider
        )
    }()

    lazy var vpnGateway: VpnGatewayProtocol = {
        VpnGateway(vpnApiService: vpnApiService,
                   appStateManager: appStateManager,
                   alertService: alertService,
                   vpnKeychain: vpnKeychain,
                   authKeychain: authKeychain,
                   siriHelper: SiriHelper(),
                   netShieldPropertyProvider: netShieldPropertyProvider,
                   natTypePropertyProvider: natTypePropertyProvider,
                   safeModePropertyProvider: safeModePropertyProvider,
                   propertiesManager: propertiesManager,
                   profileManager: profileManager,
                   availabilityCheckerResolverFactory: availabilityCheckerResolverFactory
        )
    }()
    
    init(networking: Networking,
         vpnApiService: VpnApiService,
         vpnManager: VpnManager,
         vpnKeychain: VpnKeychainProtocol,
         authKeychain: AuthKeychainHandle,
         propertiesManager: PropertiesManagerProtocol,
         sessionService: SessionService,
         netShieldPropertyProvider: NetShieldPropertyProvider,
         natTypePropertyProvider: NATTypePropertyProvider,
         safeModePropertyProvider: SafeModePropertyProvider,
         profileManager: ProfileManager,
         doh: DoHVPN,
         availabilityCheckerResolverFactory: AvailabilityCheckerResolverFactory) {
        SiriHelper.disconnectIntent = DisconnectIntent()
        SiriHelper.quickConnectIntent = QuickConnectIntent()
        self.doh = doh
        self.profileManager = profileManager
        self.networking = networking
        self.vpnApiService = vpnApiService
        self.vpnManager = vpnManager
        self.vpnKeychain = vpnKeychain
        self.authKeychain = authKeychain
        self.propertiesManager = propertiesManager
        self.sessionService = sessionService
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.natTypePropertyProvider = natTypePropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        self.configurationPreparer = VpnManagerConfigurationPreparer(vpnKeychain: vpnKeychain,
                                                                     alertService: alertService,
                                                                     propertiesManager: propertiesManager)
        self.availabilityCheckerResolverFactory = availabilityCheckerResolverFactory
        
        self.alertService.delegate = self
    }
    
    public func connect(_ completion: @escaping (QuickConnectIntentResponse) -> Void) {
        guard (try? vpnKeychain.fetch()) != nil else {
            // Not logged in so open the app
            completion(QuickConnectIntentResponse(code: .continueInApp, userActivity: nil))
            return
        }

        // Without refresh, from time to time it doesn't see newest default profile
        profileManager.refreshProfiles()
        
        propertiesManager.lastConnectionRequest = vpnGateway.quickConnectConnectionRequest(trigger: .quick)
        
        let activity = NSUserActivity(activityType: "com.protonmail.vpn.connect")
        completion(QuickConnectIntentResponse(code: .continueInApp, userActivity: activity))
    }
    
    public func disconnect(_ completion: @escaping (DisconnectIntentResponse) -> Void) {
        guard (try? vpnKeychain.fetch()) != nil else {
            // Not logged in so open the app
            completion(DisconnectIntentResponse(code: .continueInApp, userActivity: nil))
            return
        }
        
        let activity = NSUserActivity(activityType: "com.protonmail.vpn.disconnect")
        completion(DisconnectIntentResponse(code: .continueInApp, userActivity: activity))
    }

    public func getConnectionStatus(_ completion: @escaping (GetConnectionStatusIntentResponse) -> Void) {
        let status = getConnectionStatusString(connection: vpnGateway.connection)
        let response = GetConnectionStatusIntentResponse.success(status: status)

        completion(response)
    }

    private func getConnectionStatusString(connection: ConnectionStatus?) -> String {
        switch connection {
        case .connected:
            return Localizable.connected
        case .connecting:
            return Localizable.connecting
        case .disconnected:
            return Localizable.disconnected
        case .disconnecting:
            return Localizable.disconnecting
        default:
            return Localizable.vpnstatusNotLoggedin
        }
    }
    
}

extension SiriHandlerViewModel: ExtensionAlertServiceDelegate {
    
    func actionErrorReceived() {}
    
}
