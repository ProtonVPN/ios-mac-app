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

import SwiftUI
import UIKit

struct DefaultProfileRow: View {
    let viewModel: DefaultProfileViewModel

    @State private var connectionState: Int = 0

    var body: some View {
        HStack(spacing: .themeSpacing16) {
            // Left icon - same size as flag (30x20)
            Image(uiImage: viewModel.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 20)
                .foregroundColor(Color(.iconNorm()))
                .opacity(Double(viewModel.alphaOfMainElements))

            // Title
            Text(viewModel.title)
                .foregroundColor(Color(.text))
                .opacity(Double(viewModel.alphaOfMainElements))

            Spacer()

            // Connect button
            if let upgradeIcon = viewModel.imageInPlaceOfConnectIcon {
                // Upgrade badge
                Image(uiImage: upgradeIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, viewModel.connectButtonMargin)
            } else {
                // Connect button
                Button(action: {
                    viewModel.connectAction()
                }) {
                    Image(uiImage: viewModel.connectIcon ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(.iconNorm()))
                        .padding(.themeSpacing8)
                        .background(
                            Color(uiColor: viewModel.isConnected || viewModel.isConnecting
                                ? .brandColor()
                                : .weakInteractionColor()
                            )
                        )
                        .cornerRadius(.themeRadius24)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, viewModel.connectButtonMargin)
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
}

#if DEBUG
    #Preview("Fastest - Disconnected") {
        DefaultProfileRow(viewModel: .fastestMock)
            .preferredColorScheme(.dark)
    }

    #Preview("Random - Disconnected") {
        DefaultProfileRow(viewModel: .randomMock)
            .preferredColorScheme(.dark)
    }

    #Preview("With Extra Margin") {
        DefaultProfileRow(viewModel: .withExtraMarginMock)
            .preferredColorScheme(.dark)
    }

    #Preview("Connected") {
        DefaultProfileRow(viewModel: .connectedMock)
            .preferredColorScheme(.dark)
    }

    #Preview("Connecting") {
        DefaultProfileRow(viewModel: .connectingMock)
            .preferredColorScheme(.dark)
    }
#endif
