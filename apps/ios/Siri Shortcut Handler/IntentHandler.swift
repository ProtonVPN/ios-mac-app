//
//  IntentHandler.swift
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
import Intents
import NetworkExtension
import Strings

class IntentHandler: INExtension, QuickConnectIntentHandling, DisconnectIntentHandling, GetConnectionStatusIntentHandling {
    
    func handle(intent: QuickConnectIntent, completion: @escaping (QuickConnectIntentResponse) -> Void) {
        let activity = NSUserActivity(activityType: "com.protonmail.vpn.connect")
        completion(QuickConnectIntentResponse(code: .continueInApp, userActivity: activity))
    }
    
    func handle(intent: DisconnectIntent, completion: @escaping (DisconnectIntentResponse) -> Void) {
        let activity = NSUserActivity(activityType: "com.protonmail.vpn.disconnect")
        completion(DisconnectIntentResponse(code: .continueInApp, userActivity: activity))
    }

    func handle(intent: GetConnectionStatusIntent, completion: @escaping (GetConnectionStatusIntentResponse) -> Void) {
        Task {
            let status = await getVpnStatus()
            let text = self.getConnectionStatusString(status: status)
            completion(GetConnectionStatusIntentResponse.success(status: text))
        }
    }

    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }

    // MARK: -

    /// Overall, we don't expect to have more that one vpn provider manager at a time, but:
    ///
    /// We can have more than one connection configured, so OS returns array of vpn provider managers.
    /// There is also a personal VPN section that is managed not by `NETunnelProviderManager`,
    /// but by `NEVPNManager` which is used by IKEv2, so we add this as well.
    private func getVpnStatus() async -> NEVPNStatus? {
        var statuses = (try? await NETunnelProviderManager.loadAllFromPreferences().map { $0.connection.status }) ?? []

        // Add "personal" VPN status to the mix (IKEv2)
        let personal = NEVPNManager.shared()
        try? await personal.loadFromPreferences()
        statuses.append(personal.connection.status)

        // Two most important statuses are: connected and disconnected,
        // and connected > disconnected, so we can take max value, to
        // detect if we are connected to any of the configs.
        let result = statuses.max { $0.rawValue < $1.rawValue }
        return result
    }

    /// Convert VPN status into human readable string used in UI
    private func getConnectionStatusString(status: NEVPNStatus?) -> String {
        guard let status else {
            return Localizable.disconnected
        }
        switch status {
        case .connected:
            return Localizable.connected
        case .disconnected, .invalid:
            return Localizable.disconnected
        case .connecting, .reasserting:
            return Localizable.connecting
        case .disconnecting:
            return Localizable.disconnecting
        @unknown default:
            return Localizable.disconnected
        }
    }

}
