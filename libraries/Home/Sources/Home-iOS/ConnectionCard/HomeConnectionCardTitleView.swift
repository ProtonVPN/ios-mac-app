//
//  Created on 26/08/2024.
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
import Strings
import VPNAppCore
import Dependencies
import ComposableArchitecture

struct HomeConnectionCardTitleView: View {

    let store: StoreOf<HomeConnectionCardTitleFeature>

    public var body: some View {
        HStack {
            Text(store.title)
                .themeFont(.body3(emphasised: false))
                .foregroundColor(Color(.text))
            Spacer()
//            Text(Localizable.actionHelp)
//                .themeFont(.caption(emphasised: true))
//                .styled(.weak)
//            IconProvider.questionCircle
//                .resizable()
//                .styled(.weak)
//                .frame(.square(16)) // TODO: [redesign, phase 2]
        }
    }
}
