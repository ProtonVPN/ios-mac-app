//
//  Created on 01/08/2026.
//
//  Copyright (c) 2026 Proton AG
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
import Payments
import SwiftUI

/// The shell's modal launcher: everything the shell shows over the tabs takes off from this view, which rides inside
/// the pages sheet as an invisible passenger that never swaps out with a tab.
///
/// It cannot live on the backdrop, and it cannot live in a page. The backdrop always has the pages sheet presented
/// over it, and UIKit refuses a presentation from a controller that is already presenting, so a modal anchored there
/// never shows. A page only works while its tab is selected: the pages controller takes the others out of the
/// hierarchy entirely, where a destination set on one presents nothing. Inside the sheet but beside the pages is the
/// one seat that is always in the hierarchy and always free to present.
public struct ShellDestinationsView: View {
    @Bindable var store: StoreOf<TabularFeature>

    public init(store: StoreOf<TabularFeature>) {
        self.store = store
    }

    public var body: some View {
        Color.clear
            // The connection machinery's intercept and failure alerts, answerable from every tab.
            .alert($store.scope(state: \.commands.alert, action: \.commands.alert))
            // The shell's upsell: reachable from the map's pins, the status banner, and a failed intent resolution,
            // none of which belong to a page.
            .fullScreenCover(item: $store.scope(state: \.payments, action: \.payments)) { store in
                PaymentsMainView(store: store)
            }
    }
}
