//
//  Created on 23/12/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
import Search
import SwiftUI
import UIKit

struct CountryView: View {
    let viewModel: CountryItemViewModel
    let onDisplayStreamingServices: () -> Void

    var body: some View {
        List {
            ForEach(0 ..< viewModel.sectionsCount(), id: \.self) { section in
                Section {
                    ForEach(0 ..< viewModel.serversCount(for: section), id: \.self) { row in
                        let cellModel = viewModel.cellModel(for: row, section: section)
                        ServerRow(
                            viewModel: cellModel,
                            searchText: nil,
                            onStreamingInfoRequested: onDisplayStreamingServices
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(uiColor: .backgroundColor()))
                    }
                } header: {
                    if viewModel.showServerHeaders {
                        serverHeader(for: section)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .backgroundColor()))
        .navigationTitle(viewModel.countryName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(uiColor: .backgroundColor()), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func serverHeader(for section: Int) -> some View {
        let title = viewModel.titleFor(section: section)
        let hasStreamingCallback = viewModel.streamingAvailable && viewModel.isServerPlusOrAbove(for: section)

        HStack {
            Text(title)
                .themeFont(.body2(emphasised: true))
                .foregroundColor(Color(.text, .weak))

            Spacer()

            if hasStreamingCallback {
                Button(action: onDisplayStreamingServices) {
                    Image(uiImage: IconProvider.infoCircle)
                        .foregroundColor(Color(uiColor: .iconNorm()))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets())
        .background(Color(.background))
        .frame(height: UIConstants.countriesHeaderHeight)
    }
}
