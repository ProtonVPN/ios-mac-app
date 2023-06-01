//
//  Created on 2023-06-01.
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

import SwiftUI
import ConnectionDetails
import ComposableArchitecture
import ConnectionDetails_iOS

struct ContentView: View {
    var body: some View {
        VStack {
            ConnectionScreenView(store: Store(initialState: ConnectionScreenFeature.State(
                ipViewState: IPViewFeature.State(localIP: "127.0.0.1", vpnIp: "102.107.197.6"),
                connectionDetailsState: ConnectionDetailsFeature.State(connectedSince: Date.init(timeIntervalSinceNow: -12345),
                                                                       country: "Lithuania",
                                                                       city: "Siauliai",
                                                                       server: "LT#5",
                                                                       serverLoad: 23,
                                                                       protocolName: "WireGuard"), connectionFeatures: [.p2p, .tor, .smart, .streaming],
                isSecureCore: true),
                                              reducer: ConnectionScreenFeature()))

        }
    }
}

// MARK: - Previews

struct IPView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .background(Color(.background, .strong))
    }
}
