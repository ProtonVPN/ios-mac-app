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
                        ServerCellWrapper(
                            viewModel: cellModel,
                            onStreamingInfoRequested: onDisplayStreamingServices
                        )
                    }
                } header: {
                    if viewModel.showServerHeaders {
                        serverHeader(for: section)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color(uiColor: .backgroundColor()))
        .navigationTitle(viewModel.countryName)
        .navigationBarTitleDisplayMode(.inline)
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
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets())
        .background(Color(.background))
        .frame(height: UIConstants.countriesHeaderHeight)
    }
}

// MARK: - UIKit Wrapper for ServerCell

struct ServerCellWrapper: UIViewRepresentable {
    let viewModel: ServerItemViewModel
    let onStreamingInfoRequested: () -> Void

    func makeUIView(context: Context) -> UITableViewCell {
        let cell = ServerCell()
        cell.viewModel = viewModel
        cell.delegate = context.coordinator
        return cell
    }

    func updateUIView(_ uiView: UITableViewCell, context: Context) {
        if let cell = uiView as? ServerCell {
            cell.viewModel = viewModel
            cell.delegate = context.coordinator
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStreamingInfoRequested: onStreamingInfoRequested)
    }

    class Coordinator: ServerCellDelegate {
        let onStreamingInfoRequested: () -> Void

        init(onStreamingInfoRequested: @escaping () -> Void) {
            self.onStreamingInfoRequested = onStreamingInfoRequested
        }

        func userDidRequestStreamingInfo() {
            onStreamingInfoRequested()
        }
    }
}
