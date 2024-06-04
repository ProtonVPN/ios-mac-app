//
//  Created on 04/06/2024.
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

import ComposableArchitecture
import SwiftUI

struct HomeView: View {

    @Bindable var store: StoreOf<HomeFeature>

    private static let contentAllowedWidth: Double = 1460

    var body: some View {
        ScrollView {
            ProtectionStatusView(store: store.scope(state: \.protectionStatus, action: \.protectionStatus))
                .frame(width: Self.contentAllowedWidth)
            CountryListView(store: store.scope(state: \.countryList, action: \.countryList),
                            contentAllowedWidth: Self.contentAllowedWidth)
        }
        .scrollClipDisabled()
        .frame(width: Self.contentAllowedWidth)
        .onAppear {
            store.send(.connect(.initialize))
        }
    }
}
