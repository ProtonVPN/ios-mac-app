//
//  Copyright (c) 2023 Proton AG
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
import ComposableArchitecture
import VPNShared
import vpncore

extension DependencyValues {
  var connectToVPN: @Sendable (ConnectionSpec) -> Void {
    get { self[ConnectToVPNKey.self] }
    set { self[ConnectToVPNKey.self] = newValue }
  }
}

private var vpnGateway = DependencyContainer.shared.makeVpnGateway()

private enum ConnectToVPNKey: DependencyKey {
    static let liveValue: @Sendable (ConnectionSpec) -> Void = { specs in
        vpnGateway.autoConnect() // todo: connect to a proper server
    }
}
