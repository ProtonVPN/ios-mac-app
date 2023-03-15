//
//  Created on 02/03/2023.
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

import AppKit
import Combine
import SwiftUI
import AVKit
import ProtonCore_UIFoundations
import vpncore

@available(macOS 11.0, *)
struct SystemExtensionTutorialView: View {

    static let securityPreferencesUrlString = "x-apple.systempreferences:com.apple.preference.security"
    let videoTourModel = VideoTourModel(videoFile: .systemExtension)

    @State private var isFullScreen = false

    var body: some View {
        ZStack {
            videoView
                .frame(width: 864,
                       height: 512)
        }
    }

    var player: some View {
        VideoPlayer(player: videoTourModel.player)
            .cornerRadius(12)
            .onAppear(perform: videoTourModel.onAppear)
            .onDisappear {
                videoTourModel.player.pause()
            }
    }

    var descriptionView: some View {
        HStack(alignment: .center, spacing: 32) {
            VStack(alignment: .leading, spacing: 16) {
                descriptionWithMarkdown(localised: LocalizedString.sysexDescription1)
                    .foregroundColor(.init(NSColor.color(.text)))
                descriptionWithMarkdown(localised: LocalizedString.sysexDescription2)
                    .foregroundColor(.init(NSColor.color(.text)))
                if #available(macOS 13, *) {
                    descriptionWithMarkdown(localised: LocalizedString.sysexDescription3)
                        .foregroundColor(.init(NSColor.color(.text)))
                } else {
                    descriptionWithMarkdown(localised: LocalizedString.sysexDescription4)
                        .foregroundColor(.init(NSColor.color(.text)))
                }
            }
            player
        }
    }

    func descriptionWithMarkdown(localised: String) -> Text {
        var localised = localised
        if #available(macOS 12, *) {
            return Text(try! AttributedString(markdown: localised))
        } else {
            localised.removeAll { $0 == "*" }
        }
        return Text(localised)
    }

    var videoView: some View {
        return VStack(alignment: .center, spacing: 32) {
            Text(LocalizedString.sysexSetUpProtonVpn)
                .foregroundColor(.init(NSColor.color(.text)))
                .font(.system(size: 22, weight: .bold))
            descriptionView
            VStack(spacing: 16) {
                Button {
                    NSWorkspace.shared.open(URL(string: Self.securityPreferencesUrlString)!)
                } label: {
                    if #available(macOS 13, *) {
                        Text(LocalizedString.sysexOpenSystemSettings)
                    } else {
                        Text(LocalizedString.sysexOpenSecurityPreferences)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    SafariService().open(url: CoreAppConstants.ProtonVpnLinks.systemExtensionsInstallationHelp)
                } label: {
                    Text(LocalizedString.needHelp)
                }
                .buttonStyle(LinkButtonStyle())
            }
        }
        .padding(32)
    }
}
