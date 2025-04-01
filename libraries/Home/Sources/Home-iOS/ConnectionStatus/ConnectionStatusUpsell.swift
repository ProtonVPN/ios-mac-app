//
//  Created on 22/11/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Strings
import ProtonCoreUIFoundations
import HomeShared
import Dependencies
import VPNAppCore
import ComposableArchitecture
import NetShield

struct ConnectionStatusUpsell: View {

    private struct Model {
        let title: String
        let subtitle: String
        let icon: ImageAsset

        init(mode: ConnectionStatusBannerFeature.UpsellMode) {
            switch mode {
            case .netshield:
                title = Localizable.netshieldTitle
                subtitle = Localizable.netshieldUpsellSubtitle
                icon = HomeAsset.netshieldMobileSmall
            case .serverChange:
                title = Localizable.wrongCountryBannerTitle
                subtitle = Localizable.wrongCountryBannerSubtitle
                icon = HomeAsset.wrongCountrySmall
            }
        }
    }

    let mode: ConnectionStatusBannerFeature.UpsellMode

    let sendAction: ConnectionStatusBannerFeature.ActionSender

    public init(mode: ConnectionStatusBannerFeature.UpsellMode,
                sendAction: @escaping ConnectionStatusBannerFeature.ActionSender) {
        self.mode = mode
        self.sendAction = sendAction
    }

    private func label() -> some View {
        HStack(spacing: .themeSpacing12) {
            HStack(alignment: .top, spacing: .themeSpacing12) {
                let model = Model(mode: mode)
                model.icon
                    .swiftUIImage
                    .resizable()
                    .frame(.square(48))
                VStack(alignment: .leading, spacing: .themeSpacing8) {
                    Text(model.title)
                        .themeFont(.body2(emphasised: true))
                    Text(model.subtitle)
                        .themeFont(.body3(emphasised: false))
                }
            }
            IconProvider.chevronRight
                .renderingMode(.template)
                .foregroundStyle(Color(.text, .hint))
        }
        .padding(.horizontal, .themeSpacing8)
        .padding(.vertical, .themeSpacing12)
    }

    var body: some View {
        Button(action: { sendAction(.upsellTap) }, label: label)
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                sendAction(.upsellModeRefresh)
            }
    }
}
