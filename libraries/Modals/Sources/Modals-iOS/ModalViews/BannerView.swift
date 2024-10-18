//
//  Created on 13/12/2023.
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

import SwiftUI
import Theme
import Strings
import ProtonCoreUIFoundations
import Modals

struct BannerView: View {
    let useAlternateWording: Bool

    private let urlNoLogsAudit = URL(string: "https://protonvpn.com/blog/no-logs-audit/")!

    var body: some View {
        Link(destination: urlNoLogsAudit) {
            HStack(alignment: .top, spacing: .themeSpacing12) {
                Asset.bannerIcon.swiftUIImage.tint(.white)

                VStack(alignment: .leading, spacing: .themeSpacing4) {
                    HStack(spacing: 0) {
                        Text(Localizable.welcomeToProtonBannerTitle)
                            .foregroundColor(Color(.text))
                            .themeFont(.body2(emphasised: true))

                        Spacer(minLength: .themeSpacing8)

                        IconProvider.arrowOutSquare.swiftUIImage
                            .resizable()
                            .renderingMode(.template)
                            .frame(.square(16))
                            .foregroundColor(Color(.icon, .weak))
                    }

                    Text(bannerTextContent)
                        .foregroundColor(Color(.text, .weak))
                        .themeFont(.caption(emphasised: false))
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(.themeSpacing16)
        .background(Color(.background, .weak))
        .clipRectangle(cornerRadius: .radius12)
    }

    private var bannerTextContent: String {
        if useAlternateWording {
            return Localizable.welcomeToProtonBannerSubtitleRedesign
        } else {
            return Localizable.welcomeToProtonBannerSubtitle
        }
    }
}

struct BannerView_Previews: PreviewProvider {
    static var previews: some View {
        BannerView(useAlternateWording: false)
            .previewDisplayName("BannerView")
    }
}
