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

import Foundation
import ComposableArchitecture
import SwiftUI
import SwiftUINavigation

import Strings

public struct BugReportResultView: View {

    let store: StoreOf<BugReportResultFeature>

    @Environment(\.colors) var colors: Colors

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in

            // Any action in `send` will do, as we are not going to write back to error state
            IfLet(viewStore.binding(get: \.error, send: .finish), then: { error in
                AnyView(errorBody(error: error.wrappedValue, viewStore))
            }, else: {
                AnyView(successBody(viewStore))
            })
            #if os(iOS)
            .navigationBarBackButtonHidden(true)
            #endif

        })
    }

    @ViewBuilder func successBody(_ viewStore: ViewStoreOf<BugReportResultFeature>) -> some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack {
                VStack(spacing: 8) {
                    FinalIcon(state: .success)
                        .padding(.bottom, 32)
                    Text(Localizable.brSuccessTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(Localizable.brSuccessSubtitle)
                        .font(.body)
                }
                .foregroundColor(colors.textPrimary)
                .frame(maxHeight: .infinity, alignment: .center)

                Button(action: { viewStore.send(.finish) }, label: { Text(Localizable.brSuccessButton) })
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder func errorBody(error: String, _ viewStore: ViewStoreOf<BugReportResultFeature>) -> some View {
        AnyView(
            ZStack {
                colors.background.ignoresSafeArea()

                VStack {
                    VStack(spacing: 8) {
                        FinalIcon(state: .failure)
                            .padding(.bottom, 32)
                        Text(Localizable.brFailureTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(error)
                            .font(.body)
                    }
                    .foregroundColor(colors.textPrimary)
                    .frame(maxHeight: .infinity, alignment: .center)

                    Spacer()

                    VStack {
                        Button(action: { viewStore.send(.retry) }, label: { Text(Localizable.brFailureButtonRetry) })
                            .buttonStyle(PrimaryButtonStyle())

                        Button(action: { viewStore.send(.troubleshoot) }, label: { Text(Localizable.brFailureButtonTroubleshoot) })
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)

                }
            }
        )
    }

}

// MARK: - Preview

struct BugReportResultView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {

            BugReportResultView(store: Store(initialState: BugReportResultFeature.State(error: nil),
                                             reducer: { BugReportResultFeature() }))
            .previewDisplayName("Success")

            BugReportResultView(store: Store(initialState: BugReportResultFeature.State(error: "Just an error"),
                                             reducer: { BugReportResultFeature() }))
            .previewDisplayName("Error")
        }
    }
}
