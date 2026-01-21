//
//  Created on 21/01/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

/// Row view for displaying a default profile (e.g., "Fastest" connection)
// struct DefaultProfileRowView: View {
//    let store: StoreOf<DefaultProfileFeature>
//
//    var body: some View {
//        HStack(spacing: .themeSpacing12) {
//            // Profile icon
//            Image(uiImage: IconProvider.bolt)
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(width: 32, height: 32)
//                .foregroundColor(Color(.icon))
//
//            // Profile name and description
//            VStack(alignment: .leading, spacing: 2) {
//                Text(store.profileName)
//                    .themeFont(.body1())
//                    .foregroundColor(Color(.text))
//
//                Text(store.profileDescription)
//                    .themeFont(.caption())
//                    .foregroundColor(Color(.text, .weak))
//            }
//
//            Spacer()
//
//            // Connect button
//            Button(action: {
//                store.send(.connectButtonTapped)
//            }) {
//                Image(uiImage: store.isCurrentlyConnected ? IconProvider.powerOff : IconProvider.powerOn)
//                    .resizable()
//                    .frame(width: 24, height: 24)
//                    .foregroundColor(Color(.icon))
//            }
//            .buttonStyle(PlainButtonStyle())
//        }
//        .padding(.horizontal, .themeSpacing16)
//        .padding(.vertical, store.extraMargin ? .themeSpacing16 : .themeSpacing12)
//        .background(Color(uiColor: .backgroundColor()))
//    }
// }
//
// #if DEBUG
//    #Preview("Fastest Profile") {
//        DefaultProfileRowView(
//            store: Store(initialState: .mock) {
//                DefaultProfileFeature()
//            }
//        )
//        .preferredColorScheme(.dark)
//    }
//
//    #Preview("Fastest Profile - Extra Margin") {
//        DefaultProfileRowView(
//            store: Store(initialState: .mockWithExtraMargin) {
//                DefaultProfileFeature()
//            }
//        )
//        .preferredColorScheme(.dark)
//    }
// #endif
