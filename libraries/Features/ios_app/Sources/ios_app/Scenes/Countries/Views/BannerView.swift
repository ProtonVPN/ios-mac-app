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
import Theme

struct BannerView: View {
    let viewModel: BannerViewModel

    var body: some View {
        Button(action: viewModel.action) {
            HStack(spacing: .themeSpacing12) {
                Image(uiImage: viewModel.leftIcon.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)

                Text(viewModel.text)
                    .themeFont(.caption())
                    .foregroundColor(Color(.text))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(.icon, .hint))
            }
            .padding(.themeSpacing12)
            .background(Color(.background, .weak))
            .cornerRadius(.themeRadius12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, .themeSpacing8)
    }
}

#if DEBUG
    #Preview("Upsell Banner") {
        BannerView(viewModel: BannerViewModel.upsellBanner)
            .preferredColorScheme(.dark)
    }

    #Preview("Short Text") {
        BannerView(viewModel: BannerViewModel.shortText)
            .preferredColorScheme(.dark)
    }

    #Preview("Long Text") {
        BannerView(viewModel: BannerViewModel.longText)
            .preferredColorScheme(.dark)
    }

    #Preview("Custom Icon") {
        BannerView(viewModel: BannerViewModel.customIcon)
            .preferredColorScheme(.dark)
    }
#endif
