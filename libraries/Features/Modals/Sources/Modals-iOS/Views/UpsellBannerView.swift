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
import ModalsShared

public struct UpsellBannerView: View {
    let viewModel: BannerViewModel

    public init(viewModel: BannerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        SharedBannerView(viewModel: viewModel)
            .font(.caption(emphasised: false))
            .backgroundStyle(Color(.background, .weak))
    }
}

#if DEBUG
    #Preview("Upsell Banner") {
        UpsellBannerView(viewModel: BannerViewModel.upsellBanner)
            .preferredColorScheme(.dark)
    }
#endif
