//
//  Created on 12/06/2024.
//
//  Copyright (c) 2024 Proton AG
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
import enum NetworkExtension.NEVPNStatus
import CasePaths

extension NEVPNStatus: CasePathable {
    public struct AllCasePaths {
        public var disconnecting: AnyCasePath<NEVPNStatus, Void> {
            AnyCasePath(
                embed: { NEVPNStatus.disconnecting },
                extract: { guard case .disconnecting = $0 else { return nil } }
            )
        }
        public var disconnected: AnyCasePath<NEVPNStatus, Void>{
            AnyCasePath(
                embed: { NEVPNStatus.disconnected },
                extract: { guard case .disconnected = $0 else { return nil } }
            )
        }
        public var connecting: AnyCasePath<NEVPNStatus, Void> {
            AnyCasePath(
                embed: { NEVPNStatus.connecting },
                extract: { guard case .connecting = $0 else { return nil } }
            )
        }
        public var connected: AnyCasePath<NEVPNStatus, Void> {
            AnyCasePath(
                embed: { NEVPNStatus.connected },
                extract: { guard case .connected = $0 else { return nil } }
            )
        }
        public var reasserting: AnyCasePath<NEVPNStatus, Void> {
            AnyCasePath(
                embed: { NEVPNStatus.reasserting },
                extract: { guard case .reasserting = $0 else { return nil } }
            )
        }
        public var invalid: AnyCasePath<NEVPNStatus, Void> {
            AnyCasePath(
                embed: { NEVPNStatus.invalid },
                extract: { guard case .invalid = $0 else { return nil } }
            )
        }
    }

    public static var allCasePaths: AllCasePaths { AllCasePaths() }
}
