//
//  Created on 2023-05-11.
//
//  Copyright (c) 2023 Proton AG
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

#if os(macOS)
    import ComposableArchitecture
    import Foundation
    import Strings
    import SwiftUI

    public struct WhatsTheIssueView: View {
        @Perception.Bindable var store: StoreOf<WhatsTheIssueFeature>
        @Environment(\.colors) var colors: Colors

        public var body: some View {
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(alignment: .center) {
                    Text(Localizable.br1Title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(colors.textPrimary)
                        .padding(.horizontal)

                    WithPerceptionTracking {
                        List(store.state.categories) { category in
                            Button(category.label, action: {
                                store.send(.categorySelected(category), animation: .default)
                            })
                            .onHover { inside in
                                if inside {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .buttonStyle(CategoryButtonStyle())
                            .listRowBackground(colors.background)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .padding(.top, 32)
                }
                .navigationTitle(Text(Localizable.brWindowTitle))
            }
        }
    }

    // MARK: - Preview

    #Preview {
        let bugReport = MockBugReportDelegate(model: .mock)
        CurrentEnv.bugReportDelegate = bugReport

        return WhatsTheIssueView(store: Store(
            initialState: WhatsTheIssueFeature.State(categories: bugReport.model.categories),
            reducer: { WhatsTheIssueFeature() }
        )
        ).frame(width: 400.0)
    }

#endif
