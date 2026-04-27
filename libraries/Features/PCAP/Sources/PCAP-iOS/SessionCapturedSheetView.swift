//
//  Created on 2026-05-15 by Pawel Jurczyk.
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
import PCAPShared
import Strings
import SwiftUI

public struct SessionCapturedSheetView: View {
    @Bindable var store: StoreOf<SessionCapturedFeature>

    public init(store: StoreOf<SessionCapturedFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(.background)
                    .ignoresSafeArea()
                SessionCapturedView(store: store)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        store.send(.doneTapped)
                    }, label: {
                        Text(Localizable.done)
                    })
                    .buttonStyle(DefaultButtonStyle())
                }
                ToolbarItem(placement: .title) {
                    Text(Localizable.troubleshootingFile)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}
