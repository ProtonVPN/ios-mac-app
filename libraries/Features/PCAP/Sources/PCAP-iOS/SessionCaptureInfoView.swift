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
import Strings
import SwiftUI
import Theme

struct SessionCaptureInfoView: View {
    var body: some View {
        HStack(alignment: .top) {
            Theme.Asset.Icons.infoCircleFilled
                .swiftUIImage
                .resizable()
                .frame(.square(.themeSpacing16))
                .foregroundStyle(Color(.text, .weak))
            Text(.init(Localizable.pcapCaptureFileStorage(VPNLink.learnMorePCAPTroubleshooting.rawValue)))
                .themeFont(.body2(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: .themeRadius12)
                .stroke(Color(.border), lineWidth: 1)
        }
    }
}
