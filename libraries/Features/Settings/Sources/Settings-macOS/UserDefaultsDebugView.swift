//
//  Created on 11/02/2025.
//
//  Copyright (c) 2025 Proton AG
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
import Domain
import SettingsShared
import SwiftUI

struct UserDefaultsDebugView: View {
    @Binding public var store: StoreOf<UserDefaultsDebugFeature>

    var body: some View {
        VStack(spacing: 0) {
            content
            VStack {
                Button("Back to Environment Selection") { store.send(.delegate(.dismiss)) }
                Button("Reset User Defaults") { store.send(.resetDefaultsTapped) }
            }
            .padding()
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var content: some View {
        switch store.content {
        case .none:
            ProgressView()
                .task { store.send(.loadDefaults) }

        case .loading:
            ProgressView()

        case let .loadedDefaults(entries), let .loadedStandardDefaults(entries):
            List {
                defaultsList(entries: entries)
            }

        case let .failed(error):
            HStack(alignment: .center) {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                        .multilineTextAlignment(.center)
                }.padding()
            }
        }
    }

    private func defaultsList(entries: [UserDefaultsEntry]) -> some View {
        ForEach(entries, id: \.self) { entry in
            Section(entry.key) {
                if case let .bool(value) = entry.value {
                    Button {
                        store.send(.flipBool(entry))
                    } label: {
                        Text(entry.textValue())
                    }
                } else {
                    Text(entry.textValue())
                }
            }
        }
    }
}
