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

import ProtonCoreUIFoundations
import SwiftUI
import Theme

struct ExpandButtonView: View {
    let isUnderMaintenance: Bool
    var body: some View {
        HStack {
            Spacer()
            if isUnderMaintenance {
                IconProvider.wrench.swiftUIImage.resizable()
                    .frame(.square(.themeSpacing20))
                    .foregroundColor(Color(.icon, .normal))
            } else {
                IconProvider.threeDotsVertical.swiftUIImage.resizable()
                    .foregroundColor(Color(.icon, .hint))
                    .frame(.square(.themeSpacing20))
            }
        }
    }
}
