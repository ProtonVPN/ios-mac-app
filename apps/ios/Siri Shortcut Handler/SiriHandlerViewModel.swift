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
    
    private var currentAction: Action?
    private var quickConnectCompletion: ((QuickConnectIntentResponse) -> Void)?
    private var disconnectCompletion: ((DisconnectIntentResponse) -> Void)?
    
    private let alamofireWrapper: AlamofireWrapper
    private let vpnApiService: VpnApiService
    private let vpnManager: VpnManager
    private let vpnKeychain: VpnKeychainProtocol
    
    private let alertService = ExtensionAlertService()
    
    lazy var appStateManager = { [unowned self] in
        return AppStateManager(vpnApiService: vpnApiService, vpnManager: vpnManager, alamofireWrapper: alamofireWrapper, alertService: alertService, timerFactory: TimerFactory(), propertiesManager: PropertiesManager(), vpnKeychain: vpnKeychain)
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
    
    init(alamofireWrapper: AlamofireWrapper, vpnApiService: VpnApiService, vpnManager: VpnManager, vpnKeychain: VpnKeychainProtocol) {
        setUpNSCoding(withModuleName: "ProtonVPN")
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: "group.ch.protonmail.vpn")!)
        
        self.alamofireWrapper = alamofireWrapper
        self.vpnApiService = vpnApiService
        self.vpnManager = vpnManager
        self.vpnKeychain = vpnKeychain
        
        self.alertService.delegate = self
        
        if vpnGateway != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: VpnGateway.connectionChanged, object: nil)
        }
    }
    
    public func connect(_ completion: @escaping (QuickConnectIntentResponse) -> Void) {
        guard let vpnGateway = vpnGateway else {
            // Not logged in so open the app
            completion(QuickConnectIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        
        // Without refresh, from time to time it doesn't see newest default profile
        ProfileManager.shared.refreshProfiles()
        
        switch vpnGateway.connection {
        case .connected, .connecting:
            quickConnectCompletion = completion
            currentAction = .reconnect
            vpnGateway.disconnect {
                vpnGateway.quickConnect()
            }
            
        case .disconnected, .disconnecting:
            quickConnectCompletion = completion
            currentAction = .quickConnect
            vpnGateway.quickConnect()
        }
    }
    
    public func disconnect(_ completion: @escaping (DisconnectIntentResponse) -> Void) {
        guard let vpnGateway = vpnGateway else {
            // Not logged in so open the app
            completion(DisconnectIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        
        switch vpnGateway.connection {
        case .connected:
            disconnectCompletion = completion
            currentAction = .disconnect
            vpnGateway.disconnect()
            
        case .connecting:
            vpnGateway.stopConnecting(userInitiated: true)
            completion(DisconnectIntentResponse(code: .success, userActivity: nil))
            
        case .disconnected, .disconnecting:
            completion(DisconnectIntentResponse(code: .success, userActivity: nil))
        }
    }
    
    public func getConnectionStatus(_ completion: @escaping (GetConnectionStatusIntentResponse) -> Void) {
        guard let vpnGateway = vpnGateway else {
            // Not logged in so open the app
            completion(GetConnectionStatusIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        
        let status = getConnectionStatusString(connection: vpnGateway.connection)
        let response = GetConnectionStatusIntentResponse.success(status: status)
        
        completion(response)
    }
    
    private func getConnectionStatusString(connection: ConnectionStatus) -> String {
        switch connection {
        case .connected:
            return LocalizedString.connected
        case .connecting:
            return LocalizedString.connecting
        case .disconnected:
            return LocalizedString.disconnected
        case .disconnecting:
            return LocalizedString.disconnecting
        }
    }
    
    @objc private func connectionChanged() {
        guard let currentAction = currentAction else { return }
        
        switch currentAction {
        case .quickConnect:
            connectedSuccessfully()
            
        case .disconnect:
            disconnectedSuccessfully()
            
        case .reconnect:
            if vpnGateway?.connection == .connected {
                connectedSuccessfully()
            }
        }
    }
    
    private func connectedSuccessfully() {
        guard let completion = quickConnectCompletion else {
            self.currentAction = nil
            return
        }
        guard let vpnGateway = vpnGateway else { return }
        
        switch vpnGateway.connection {
        case .connected:
            completion(QuickConnectIntentResponse(code: .success, userActivity: nil))
            quickConnectCompletion = nil
        case .disconnected, .disconnecting:
            completion(QuickConnectIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            quickConnectCompletion = nil
        default:
            break // Do nothing
        }
    }
    
    private func disconnectedSuccessfully() {
        guard let completion = disconnectCompletion else {
            self.currentAction = nil
            return
        }
        guard let vpnGateway = vpnGateway else { return }
        
        switch vpnGateway.connection {
        case .connected:
            completion(DisconnectIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            disconnectCompletion = nil
        case .disconnected:
            completion(DisconnectIntentResponse(code: .success, userActivity: nil))
            disconnectCompletion = nil
        default:
            break // Do nothing
        }
    }
    
    enum Action {
        case quickConnect
        case disconnect
        case reconnect
    }
    
}

@available(iOSApplicationExtension 12.0, *)
extension SiriHandlerViewModel: ExtensionAlertServiceDelegate {
    
    func actionErrorReceived() {
        if disconnectCompletion != nil {
            disconnectCompletion?(DisconnectIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            disconnectCompletion = nil
        }
        if quickConnectCompletion != nil {
            quickConnectCompletion?(QuickConnectIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
            quickConnectCompletion = nil
        }
    }
    
}
