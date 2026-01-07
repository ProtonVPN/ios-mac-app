//
//  Created on 23/12/2025 by Max Kupetskyi.
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

import SwiftUI
import Theme
import UIKit

public struct CountryRow: View {
    let viewModel: CountryViewModel
    let searchText: String?

    @State private var connectionState: Int = 0

    public init(viewModel: CountryViewModel, searchText: String? = nil) {
        self.viewModel = viewModel
        self.searchText = searchText
    }

    public var body: some View {
        HStack(spacing: .themeSpacing12) {
            // Flag(s) and country name
            leadingContent

            Spacer()

            // Feature icons on the right
            featureIcons

            // Connect button (if enabled)
            if viewModel.showCountryConnectButton {
                connectButton
            }

            // Chevron (hidden only when showing upgrade text)
            if viewModel.textInPlaceOfConnectIcon == nil {
                chevronIcon
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onAppear {
            viewModel.connectionChanged = {
                connectionState += 1
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var leadingContent: some View {
        HStack(spacing: viewModel.isSecureCoreCountry ? .themeSpacing8 : .themeSpacing16) {
            if viewModel.isSecureCoreCountry {
                secureCoreIcon
            }

            if let flagImage = viewModel.flag {
                flagView(flagImage)
            }

            countryNameText
        }
    }

    @ViewBuilder
    private var secureCoreIcon: some View {
        Image("ic-chevrons-right", bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
            .foregroundColor(Color(uiColor: .brandColor()))
    }

    @ViewBuilder
    private func flagView(_ flagImage: UIImage) -> some View {
        Image(uiImage: flagImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 30, height: 20)
            .cornerRadius(viewModel.isGateway ? 0 : .themeRadius4)
            .clipped()
            .opacity(Double(viewModel.alphaOfMainElements))
    }

    @ViewBuilder
    private var countryNameText: some View {
        if let searchText, !searchText.isEmpty {
            highlightedText(viewModel.description, searchText: searchText)
                .opacity(Double(viewModel.alphaOfMainElements))
        } else {
            Text(viewModel.description)
                .foregroundColor(Color(uiColor: viewModel.textColor))
                .opacity(Double(viewModel.alphaOfMainElements))
        }
    }

    @ViewBuilder
    private var featureIcons: some View {
        HStack(spacing: .themeSpacing8) {
            if viewModel.p2pAvailable, viewModel.showFeatureIcons {
                featureIcon(named: "ic-arrows-switch")
            }

            if viewModel.torAvailable, viewModel.showFeatureIcons {
                featureIcon(named: "ic-brand-tor")
            }

            if viewModel.isSmartAvailable, viewModel.showFeatureIcons {
                featureIcon(named: "ic-globe")
            }
        }
    }

    @ViewBuilder
    private func featureIcon(named name: String) -> some View {
        Image(name, bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
            .foregroundColor(.white)
            .opacity(Double(viewModel.alphaOfMainElements))
    }

    @ViewBuilder
    private var chevronIcon: some View {
        Image("ic-chevron-right", bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 38)
            .foregroundColor(Color(.icon, .weak))
    }

    @ViewBuilder
    private var connectButton: some View {
        if let connectIcon = viewModel.connectIcon {
            // Connect button with icon (interactive)
            Button(action: {
                viewModel.connectAction()
            }) {
                ZStack {
                    Circle()
                        .foregroundStyle(Color(uiColor: viewModel.connectButtonColor))
                        .frame(.square(36))
                    Image(uiImage: connectIcon)
                        .aspectRatio(contentMode: .fit)
                }
            }
            .buttonStyle(PlainButtonStyle())
        } else if let text = viewModel.textInPlaceOfConnectIcon {
            // Upgrade button with text
            Text(text)
                .themeFont(.caption())
                .foregroundColor(Color(uiColor: viewModel.textColor))
                .padding(.horizontal, .themeSpacing16)
                .padding(.vertical, .themeSpacing8)
                .background(Color(uiColor: viewModel.connectButtonColor))
                .cornerRadius(.themeRadius8)
        }
    }

    private func highlightedText(_ text: String, searchText: String) -> Text {
        let lowercasedText = text.lowercased()
        let lowercasedSearch = searchText.lowercased()

        if let range = lowercasedText.range(of: lowercasedSearch) {
            let beforeMatch = String(text[..<range.lowerBound])
            let match = String(text[range])
            let afterMatch = String(text[range.upperBound...])

            return Text(beforeMatch)
                .foregroundColor(Color(uiColor: viewModel.textColor))
                + Text(match)
                .foregroundColor(.yellow)
                .fontWeight(.bold)
                + Text(afterMatch)
                .foregroundColor(Color(uiColor: viewModel.textColor))
        }

        return Text(text)
            .foregroundColor(Color(uiColor: viewModel.textColor))
    }
}

#Preview("Normal") {
    CountryRow(viewModel: CountryViewModelMock.normal, searchText: nil)
        .preferredColorScheme(.dark)
}

#Preview("Upgrade") {
    CountryRow(viewModel: CountryViewModelMock.upgrade, searchText: nil)
        .preferredColorScheme(.dark)
}

#Preview("Secure Core") {
    CountryRow(viewModel: CountryViewModelMock.secureCore, searchText: nil)
        .preferredColorScheme(.dark)
}

#Preview("With Flag") {
    CountryRow(viewModel: CountryViewModelMock.withFlag, searchText: nil)
        .preferredColorScheme(.dark)
}

#Preview("No Connect Button") {
    CountryRow(viewModel: CountryViewModelMock.noConnectButton, searchText: nil)
        .preferredColorScheme(.dark)
}

#Preview("Search Highlight") {
    CountryRow(viewModel: CountryViewModelMock.normal, searchText: "Coun")
        .preferredColorScheme(.dark)
}
