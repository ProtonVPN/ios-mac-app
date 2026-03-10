//
//  Created on 2026-01-19 by Pawel Jurczyk.
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

import SwiftUI
import Theme

struct ConnectButtonView: View {
    let isUnderMaintenance: Bool
    let shouldConnect: Bool

    var body: some View {
        ZStack {
            if isUnderMaintenance {
                Asset.Icons.wrench.swiftUIImage
                    .foregroundColor(Color(.icon, .weak))
                    .frame(.square(40))
            } else {
                let style: AppTheme.Style = shouldConnect ? [.interactive, .weak] : [.interactive]
                Circle()
                    .foregroundStyle(Color(.background, style))
                    .frame(.square(40))
                Asset.Icons.powerOff.swiftUIImage
            }
        }
    }
}

#if DEBUG
    #Preview("Connect") {
        ConnectButtonView(isUnderMaintenance: false, shouldConnect: true)
            .padding()
            .preferredColorScheme(.dark)
    }

    #Preview("Connected") {
        ConnectButtonView(isUnderMaintenance: false, shouldConnect: false)
            .padding()
            .preferredColorScheme(.dark)
    }

    #Preview("Maintenance") {
        ConnectButtonView(isUnderMaintenance: true, shouldConnect: false)
            .padding()
            .preferredColorScheme(.dark)
    }
#endif
