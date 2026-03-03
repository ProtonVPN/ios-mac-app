//
//  Created on 09/02/2026 by Max Kupetskyi.
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
import SwiftUI

struct LogsView: View {
    @Bindable var store: StoreOf<LogsFeature>

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading logs...")
                    .focusable()
            } else if store.logs.isEmpty {
                Text("No logs available.")
                    .foregroundStyle(Color(.text, .weak))
                    .focusable()
            } else {
                ScrollableTextView(text: store.logs, linesPerChunk: 40, alignment: .leading)
                    .font(.system(.footnote, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { store.send(.onAppear) }
        .onExitCommand { store.send(.onExitCommand) }
        .safeAreaInset(edge: .top, spacing: 0) {
            ZStack {
                HStack {
                    Spacer()
                    Text(LocalizedStringKey(store.title))
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
            }
            .padding(.horizontal, .themeSpacing32)
            .padding(.vertical, .themeSpacing16)
            .background(.ultraThinMaterial)
        }
    }
}
