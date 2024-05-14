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
import ComposableArchitecture

struct CreateAccountView: View {
    
    var store: StoreOf<CreateAccountFeature>

    var body: some View {
        HStack {
            VStack(spacing: .themeSpacing32) {
                HStack(spacing: 0) {
                    Text("Create your Proton Account")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer(minLength: 0)
                }
                HStack {
                    Text("Scan the QR code or go to\n")
                        .font(.title3)
                        .foregroundStyle(Color(.text, .weak)) +
                    Text("protonvpn.com/tv")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(.text, .interactive))
                    Spacer(minLength: 0)
                }
                
                
            }
            .frame(maxWidth: 800)
            QRCodeView(string: "www.protonvpn.com/tv")
        }
    }
}
