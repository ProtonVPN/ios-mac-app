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
    private static let columnWidth: CGFloat = 780

    var store: StoreOf<UpsellFeature>

    var body: some View {
        HStack(alignment: .center) {
            UpsellCoaxingView()
                .frame(width: Self.columnWidth)
            switch store.state {
            case .loaded(let products, false):
                PurchaseOptionsView(products: products, sendAction: { _ = store.send($0) })
                    .frame(width: Self.columnWidth)

            default:
                ProgressView()
                    .frame(width: Self.columnWidth)
            }
        }
        .onExitCommand {
            store.send(.onExit)
        }
    }
}
