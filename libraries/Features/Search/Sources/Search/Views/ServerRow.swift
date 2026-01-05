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

public struct ServerRow: View {
    let viewModel: ServerViewModel
    let searchText: String?
    let onStreamingInfoRequested: (() -> Void)?

    @State private var connectionState: Int = 0

    public init(
        viewModel: ServerViewModel,
        searchText: String? = nil,
        onStreamingInfoRequested: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.searchText = searchText
        self.onStreamingInfoRequested = onStreamingInfoRequested
    }

    public var body: some View {
        HStack(spacing: .themeSpacing12) {
            // Left side: Flags or content
            if viewModel.entryCountryName != nil {
                // Secure Core mode
                secureCoreContent
            } else {
                // Regular server mode
                regularServerContent
            }

            Spacer()

            // Right side: Load indicator, feature icons, and connect button
            HStack(spacing: .themeSpacing12) {
                // Load indicator
                if !viewModel.underMaintenance, !viewModel.isUsersTierTooLow {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(uiColor: viewModel.loadColor))
                            .frame(width: 8, height: 8)
                        Text("\(viewModel.load)%")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.text, .weak))
                            .fixedSize()
                    }
                    .fixedSize()
                }

                // Feature icons
                HStack(spacing: .themeSpacing8) {
                    if viewModel.isP2PAvailable {
                        Image("ic-arrows-switch", bundle: .module)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                            .opacity(Double(viewModel.alphaOfMainElements))
                    }

                    if viewModel.isTorAvailable {
                        Image("ic-brand-tor", bundle: .module)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                            .opacity(Double(viewModel.alphaOfMainElements))
                    }

                    if viewModel.isSmartAvailable {
                        Image("ic-globe", bundle: .module)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundColor(.white)
                            .opacity(Double(viewModel.alphaOfMainElements))
                    }

                    if viewModel.isStreamingAvailable {
                        Button(action: {
                            onStreamingInfoRequested?()
                        }) {
                            Image("ic-play", bundle: .module)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                                .opacity(Double(viewModel.alphaOfMainElements))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Connect button
                connectButton
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

    @ViewBuilder
    private var secureCoreContent: some View {
        HStack(spacing: .themeSpacing8) {
            // Entry flag
            if let entryFlag = viewModel.entryCountryFlag {
                Image(uiImage: entryFlag)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 20)
                    .cornerRadius(.themeRadius4)
                    .clipped()
                    .opacity(Double(viewModel.alphaOfMainElements))
            }

            // Chevrons
            Image("ic-chevrons-right", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .opacity(Double(viewModel.alphaOfMainElements))
                .foregroundColor(Color(uiColor: .brandColor()))

            // Exit flag
            if let exitFlag = viewModel.countryFlag {
                Image(uiImage: exitFlag)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 30, height: 20)
                    .cornerRadius(.themeRadius4)
                    .clipped()
                    .opacity(Double(viewModel.alphaOfMainElements))
            }

            // Country name
            if let searchText, !searchText.isEmpty {
                highlightedText(viewModel.countryName, searchText: searchText)
                    .opacity(Double(viewModel.alphaOfMainElements))
            } else {
                Text(viewModel.countryName)
                    .foregroundColor(Color(uiColor: viewModel.textColor))
                    .opacity(Double(viewModel.alphaOfMainElements))
            }
        }
    }

    @ViewBuilder
    private var regularServerContent: some View {
        VStack(alignment: .leading, spacing: .themeSpacing2) {
            // Server name
            if let searchText, !searchText.isEmpty {
                highlightedText(viewModel.description, searchText: searchText)
                    .opacity(Double(viewModel.alphaOfMainElements))
            } else {
                Text(viewModel.description)
                    .foregroundColor(Color(uiColor: viewModel.textColor))
                    .opacity(Double(viewModel.alphaOfMainElements))
            }

            // City name
            Text(viewModel.displayCityName)
                .font(.system(size: 13))
                .foregroundColor(Color(.text, .weak))
                .opacity(Double(viewModel.alphaOfMainElements))
        }
    }

    @ViewBuilder
    private var connectButton: some View {
        if let text = viewModel.textInPlaceOfConnectIcon {
            // Upgrade button
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(uiColor: viewModel.textColor))
                .padding(.horizontal, .themeSpacing16)
                .padding(.vertical, .themeSpacing8)
                .background(Color(uiColor: viewModel.connectButtonColor))
                .cornerRadius(.themeRadius8)
                .fixedSize()
        } else if let connectIcon = viewModel.connectIcon {
            // Connect button with icon
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
    ServerRow(
        viewModel: ServerViewModelMock.normal,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Secure Core") {
    ServerRow(
        viewModel: ServerViewModelMock.secureCore,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Secure Core with Flags") {
    ServerRow(
        viewModel: ServerViewModelMock.secureCoreWithFlags,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Under Maintenance") {
    ServerRow(
        viewModel: ServerViewModelMock.underMaintenance,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Upgrade") {
    ServerRow(
        viewModel: ServerViewModelMock.upgrade,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Streaming") {
    ServerRow(
        viewModel: ServerViewModelMock.streaming,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("High Load") {
    ServerRow(
        viewModel: ServerViewModelMock.highLoad,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Low Load") {
    ServerRow(
        viewModel: ServerViewModelMock.lowLoad,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Translated City") {
    ServerRow(
        viewModel: ServerViewModelMock.translatedCity,
        searchText: nil,
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Search Highlight") {
    ServerRow(
        viewModel: ServerViewModelMock.normal,
        searchText: "NY",
        onStreamingInfoRequested: nil
    )
    .preferredColorScheme(.dark)
}
