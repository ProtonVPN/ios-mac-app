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
        content
            .navigationTitle(store.isStandard ? "Standard User Defaults" : "User Defaults")
            .refreshable { load() }
            .alert($store.scope(state: \.alert, action: \.alert))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "trash")
                        .onTapGesture { store.send(.resetDefaultsTapped) }
                        .disabled(!resetEnabled)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.content {
        case .none:
            ProgressView()
                .task {
                    load()
                }

        case .loading:
            ProgressView()

        case let .loadedDefaults(entries):
            Form {
                defaultsList(entries: entries)
            }

        case let .loadedStandardDefaults(entries):
            Form {
                defaultsList(entries: entries)
            }

        case let .failed(error):
            HStack(alignment: .center) {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                        .multilineTextAlignment(.center)
                }.padding(.horizontal, 100)
            }
        }
    }

    private func defaultsList(entries: [UserDefaultsEntry]) -> some View {
        ForEach(entries, id: \.self) { entry in
            Section {
                if case let .bool(value) = entry.value {
                    Button {
                        store.send(.flipBool(entry))
                    } label: {
                        Text(entry.textValue())
                    }
                } else {
                    Text(entry.textValue())
                }
            } footer: {
                Text(entry.key)
            }
        }
    }

    private var resetEnabled: Bool {
        if store.isStandard {
            store.content.is(\.loadedStandardDefaults)
        } else {
            store.content.is(\.loadedDefaults)
        }
    }

    private func load() {
        if store.isStandard {
            store.send(.loadStandardDefaults)
        } else {
            store.send(.loadDefaults)
        }
    }
}
