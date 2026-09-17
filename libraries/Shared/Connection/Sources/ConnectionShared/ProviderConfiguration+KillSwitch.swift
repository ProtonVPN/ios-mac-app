//
//  Created on 21/08/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if !os(tvOS)
    import NetworkExtension

    public extension NEVPNProtocol {
        /// Routes traffic that Apple excludes from the tunnel by default back into it. Even with
        /// `includeAllNetworks` set, the system keeps three kinds of traffic outside the tunnel
        /// unless these flags are cleared: push notifications (APNs), internet-routable carrier
        /// services (Wi-Fi Calling, MMS, Visual Voicemail), and communication with devices attached
        /// over USB or Wi-Fi. Advanced kill switch promises to block everything the platform can
        /// block, so it clears all three. That traffic then flows through the tunnel while
        /// connected. The system drops it while the tunnel is connecting, re-establishing, or
        /// blocking with zero peers. A torn-down tunnel enforces nothing. Standard keeps the system
        /// defaults, so notifications and carrier features keep working outside the tunnel.
        func applyAdvancedKillSwitchExclusions() {
            excludeCellularServices = false
            excludeAPNs = false
            if #available(iOS 17.4, macOS 14.4, *) {
                excludeDeviceCommunication = false
            }
        }
    }
#endif
