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

public struct SharedBannerView: View {
    let viewModel: BannerViewModel

    public init(viewModel: BannerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Button(action: viewModel.action) {
            HStack(spacing: .themeSpacing12) {
                viewModel.leftIcon.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)

                Text(viewModel.text)
                    .foregroundColor(Color(.text))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                SwiftUI.Image(systemName: "chevron.right")
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(.icon, .hint))
            }
            .padding(.themeSpacing12)
            .background(in: RoundedRectangle(cornerRadius: .themeRadius12))
        }
        .buttonStyle(.plain)
        .padding(.vertical, .themeSpacing8)
    }
}

#if DEBUG
    #Preview("Upsell Banner") {
        SharedBannerView(viewModel: BannerViewModel.upsellBanner)
            .backgroundStyle(Color(.background, .transparent))
            .preferredColorScheme(.dark)
            .padding()
            .background(.red)
    }

    #Preview("Short Text") {
        SharedBannerView(viewModel: BannerViewModel.shortText)            .backgroundStyle(Color(.background, .weak))
            .preferredColorScheme(.dark)
            .padding()
    }

    #Preview("Long Text") {
        SharedBannerView(viewModel: BannerViewModel.longText)
            .preferredColorScheme(.dark)
            .padding()
    }

    #Preview("Custom Icon") {
        SharedBannerView(viewModel: BannerViewModel.customIcon)
            .preferredColorScheme(.dark)
            .padding()
    }
#endif
