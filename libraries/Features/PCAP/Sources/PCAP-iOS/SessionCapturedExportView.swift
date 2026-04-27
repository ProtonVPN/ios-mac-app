//
//  Created on 2026-05-12 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import Domain
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

public struct SessionCapturedExportView: View {
    let url: URL

    public var body: some View {
        VStack(spacing: .themeSpacing24) {
            IconProvider.checkmarkCircleFilled.swiftUIImage.resizable()
                .frame(.square(.themeSpacing24))
                .foregroundStyle(Color(.icon, .success))
            VStack(spacing: .themeSpacing16) {
                Text(Localizable.pcapCaptureSessionCaptured)
                    .themeFont(.body1(.bold))
                    .foregroundStyle(Color(.text))
                Text(.init(Localizable.pcapCaptureFileSharing(VPNLink.drive.rawValue)))
                    .themeFont(.body2(emphasised: false))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(.text, .weak))
            }
            HStack(spacing: .themeSpacing8) {
                IconProvider.fileLines
                    .resizable()
                    .frame(.square(.themeSpacing16))
                Text(url.lastPathComponent)
                    .themeFont(.body2(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
            }
            .padding(.horizontal, .themeSpacing12)
            .padding(.vertical, .themeSpacing8)
            .background {
                RoundedRectangle(cornerRadius: .themeRadius8)
                    .stroke(Color(.border), lineWidth: 1)
            }
            ShareLink(Localizable.pcapCaptureSessionExport, item: url)
                .buttonStyle(ThemeButtonStyle(padding: .medium, style: .secondary))
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing32)
        .background(
            Color(.background, .weak),
            in: RoundedRectangle(cornerRadius: .themeRadius12)
        )
    }
}

#Preview {
    SessionCapturedExportView(url: .init(string: "file.pcap")!)
        .colorScheme(.dark)
}
