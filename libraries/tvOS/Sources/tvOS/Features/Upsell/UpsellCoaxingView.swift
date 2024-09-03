//
//  Created on 22/08/2024.
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

import SwiftUI

struct UpsellCoaxingView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(.vpnSubscriptionBadge)
            Spacer()
                .frame(height: 48)
            Text("Upgrade your privacy")
                .multilineTextAlignment(.center)
                .font(.title)
                .bold()
            Spacer()
                .frame(height: 24)
            Text("To unlock lightning-fast streaming with servers in 100+ countries, subscribe to VPN Plus.")
                .multilineTextAlignment(.center)
                .font(.system(size: 38, weight: .regular))
                .opacity(0.8)
            Spacer()
                .frame(height: 72)
            UpsellFeatureListView()
                .themeBorder(color: Color(.border),
                             lineWidth: 1,
                             cornerRadius: .radius32)
        }
    }
}
