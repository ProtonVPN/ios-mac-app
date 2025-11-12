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
import SettingsShared
import SwiftUI

struct UserDefaultsDebugView: View {
    @Binding public var store: StoreOf<UserDefaultsDebugFeature>

    var body: some View {
        content
            .padding()
            .navigationTitle("User Defaults")
            .refreshable { store.send(.loadDefaults) }
            .alert($store.scope(state: \.alert, action: \.alert))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "trash")
                        .onTapGesture { store.send(.resetDefaultsTapped) }
                        .disabled(!store.content.is(\.loaded))
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.content {
        case .none:
            ProgressView()
                .task { store.send(.loadDefaults) }

        case .loading:
            ProgressView()

        case let .loaded(entries):
            defaultsList(entries: entries)

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
        Form {
            ForEach(entries, id: \.self) { entry in
                HStack {
                    Text(entry.key)
                    Spacer()
                    Text(textValue(forEntry: entry))
                }
            }
        }
    }

    private func textValue(forEntry entry: UserDefaultsEntry) -> String {
        switch entry.value {
        case let .bool(boolValue):
            String(boolValue)

        case let .data(data):
            "Data(\(data.count) bytes)"

        case let .int(intValue):
            String(intValue)

        case let .string(string), let .utf8(string), let .unknown(string):
            string.count > 80 ? string.prefix(80) + "..." : string
        }
    }
}
