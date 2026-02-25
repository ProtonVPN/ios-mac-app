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

//import LegacyCommon
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

struct ServersFeaturesInformationView: View {
    let viewModel: ServersFeaturesInformationViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            ZStack {
                Text(Localizable.informationTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                HStack {
                    Button(action: onDismiss) {
                        Image(uiImage: IconProvider.crossBig)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .padding(3)
                    }
                    .padding(.leading, .themeSpacing12)

                    Spacer()
                }
            }
            .frame(height: 44)
            .padding(.top, .themeSpacing8)

            // Features list
            List {
                ForEach(0 ..< viewModel.totalFeatures, id: \.self) { section in
                    Section {
                        ForEach(0 ..< viewModel.featuresCount(for: section), id: \.self) { row in
                            let featureViewModel = viewModel.getFeatureViewModel(
                                indexPath: IndexPath(row: row, section: section)
                            )
                            FeatureRow(viewModel: featureViewModel)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        if let title = viewModel.titleFor(section) {
                            Text(title)
                                .themeFont(.body2(emphasised: false))
                                .foregroundColor(Color(.text, .weak))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, .themeSpacing16)
                                .frame(height: viewModel.headerHeight)
                                .listRowInsets(EdgeInsets())
                                .background(Color(uiColor: .backgroundColor()))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(uiColor: .backgroundColor()))
        }
        .background(Color(uiColor: .backgroundColor()))
    }
}

#if DEBUG
    #Preview("All Features") {
        ServersFeaturesInformationView(viewModel: ServersFeaturesInformationViewModelImplementation.mock, onDismiss: {})
            .preferredColorScheme(.dark)
    }

    #Preview("Multiple Sections") {
        ServersFeaturesInformationView(viewModel: ServersFeaturesInformationViewModelImplementation.multipleSections, onDismiss: {})
            .preferredColorScheme(.dark)
    }

    #Preview("No Titles") {
        ServersFeaturesInformationView(viewModel: ServersFeaturesInformationViewModelImplementation.noTitles, onDismiss: {})
            .preferredColorScheme(.dark)
    }

    #Preview("Single Feature") {
        ServersFeaturesInformationView(viewModel: ServersFeaturesInformationViewModelImplementation.singleFeature, onDismiss: {})
            .preferredColorScheme(.dark)
    }
#endif
