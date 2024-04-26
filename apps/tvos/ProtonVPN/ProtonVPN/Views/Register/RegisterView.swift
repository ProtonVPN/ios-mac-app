//
//  Created on 23/04/2024.
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

struct CreateAccountView: View {
    var body: some View {
        VStack(spacing: 169) {
            Image(.vpnWordmarkNoBg)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 290)
            HStack {
                VStack(spacing: .themeSpacing64) {
                    HStack {
                        Text("Create your Proton Account")
                            .font(.title)
                        Spacer(minLength: 0)
                    }
                    HStack {
                        Text("Scan the QR code or go to protonvpn.com/tv.")
                            .font(.title2)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: 800)
                QRCodeView(string: "www.protonvpn.com/tv")
            }
        }
    }
}
