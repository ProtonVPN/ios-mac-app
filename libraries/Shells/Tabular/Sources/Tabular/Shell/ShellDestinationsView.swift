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
import Home
import ModalsShared
import Payments
import SwiftUI

/// Presents everything the shell shows over the tabs. The view draws nothing; it exists so the shell's modal
/// presentations have an anchor that is always in the view hierarchy.
///
/// Neither the backdrop nor a page can be that anchor. The backdrop always has the pages sheet presented over
/// it, and UIKit cannot present from a controller that is already presenting. A page works only while its tab is
/// selected: the pages controller removes the other pages from the hierarchy, and a presentation anchored
/// outside the hierarchy never shows. So this view is installed beside the pages, inside the sheet, where it is
/// always present and always free to present.
struct ShellDestinationsView: View {
    @Bindable var store: StoreOf<TabularFeature>

    var body: some View {
        Color.clear
            // The connection machinery's intercept and failure alerts, answerable from every tab.
            .alert($store.scope(state: \.commands.alert, action: \.commands.alert))
            // The shell's upsell: reachable from the map's pins, the status banner, and a failed intent resolution,
            // none of which belong to a page.
            .fullScreenCover(item: $store.scope(state: \.payments, action: \.payments)) { store in
                PaymentsMainView(store: store)
            }
            // The two-factor notice: the connection machinery raises it above the tabs, so it presents here,
            // where it shows whichever tab is up.
            .sheet(item: $store.scope(state: \.localAgentNotice, action: \.localAgentNotice)) { store in
                LocalAgentNoticeView(store: store)
            }
            // The telemetry question, asked of the signed-in app rather than of a tab. Not dismissible by
            // swiping: leaving the switches alone and confirming is an answer, so there is always a way out, and
            // an unanswered question would otherwise be asked again at every launch.
            .sheet(item: $store.scope(state: \.telemetryConsent, action: \.telemetryConsent)) { store in
                TelemetryConsentView(store: store)
                    .interactiveDismissDisabled()
            }
    }
}
