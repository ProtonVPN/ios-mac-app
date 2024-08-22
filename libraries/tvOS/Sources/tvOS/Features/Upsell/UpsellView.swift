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
import Theme
import ProtonCoreUIFoundations
import ComposableArchitecture
import struct StoreKit.Product

struct UpsellView: View {

    var store: StoreOf<UpsellFeature>

    var body: some View {
        HStack(alignment: .center) {
            UpsellCoaxingView()
                .frame(width: 780)
            switch store.state {
            case .loading:
                ProgressView()
                    .frame(width: 780)
            case .loaded(let products):
                PurchaseOptionsView(products: products,
                                    sendAction: { _ = store.send($0) })
                    .frame(width: 780)
            }
        }
        .onExitCommand {
            store.send(.onExit)
        }
    }
}
