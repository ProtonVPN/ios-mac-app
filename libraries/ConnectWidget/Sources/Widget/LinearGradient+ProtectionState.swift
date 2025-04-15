//
//  Created on 2025-04-10 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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

import SwiftUI

extension LinearGradient {
    static func forProtectionState(_ protectionState: ConnectWidgetEntry.ProtectionState) -> LinearGradient {
        let startColor: Color
        switch protectionState {
        case .signedOut:
            return .linearGradient(stops: [.init(color: Color(.loggedOutGradientStart), location: 0),
                                           .init(color: Color(.loggedOutGradientStop), location: 0.7)],
                                   startPoint: .topTrailing,
                                   endPoint: .bottomLeading)
        case .protected:
            startColor = Color(.icon, .vpnGreen)
        case .unprotected:
            startColor = Color(.background, .danger)
        case .protecting:
            startColor = .white
        }

        return .linearGradient(stops: [.init(color: startColor.opacity(0.5), location: 0),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top,
                               endPoint: .center)
    }
}
