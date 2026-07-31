//
//  Created on 29/07/2026.
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
import Home
import SwiftUI

/// The shell's own view of the backdrop: the globe and connection chrome with the sheet's current overlap applied, so
/// the map's focus region tracks where the sheet rests. The layout itself stays in `GlobeBackdropView`, which knows
/// nothing about sheets and renders overlap zero in previews and snapshots.
public struct TabularBackdropView: View {
    @Bindable var store: StoreOf<TabularFeature>
    /// Tracks the sheet as it moves, so the globe follows the drag rather than easing after it lands.
    let overlap: SheetOverlap

    public init(store: StoreOf<TabularFeature>, overlap: SheetOverlap) {
        self.store = store
        self.overlap = overlap
    }

    public var body: some View {
        GlobeBackdropView(
            map: store.scope(state: \.map, action: \.map),
            status: store.scope(state: \.connectionStatus, action: \.connectionStatus),
            bottomOverlap: overlap.points,
            restingOverlap: overlap.restingPoints,
            // The interactive layer is in hand only with the sheet on its bar; at half the globe keeps its city dots
            // and re-centers on the connection.
            showsInteractivePins: store.detent == .bar
        )
        // No animation attached here: drag reports arrive with the sheet's own cadence, and a settle report carries its
        // spring from the shell's observer.
        //
        // The connection machinery's intercept alerts present from here, the one view on screen from every tab, rather
        // than from a page the sheet may be hiding.
        .alert($store.scope(state: \.commands.alert, action: \.commands.alert))
    }
}
