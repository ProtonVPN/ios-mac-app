//
//  Created on 05/12/2024.
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
import Dependencies
import Theme
import SharedViews
import Domain
import Home
import ProtonCoreUIFoundations

struct ConnectionPreferenceView: View {
    @Dependency(\.locale) private var locale
    static let itemCellHeight: CGFloat = .themeSpacing64

    let model: ConnectionPreferenceModel
    let isSelected: Bool
    let sendAction: DefaultConnectionFeature.ActionSender

    init(
        model: ConnectionPreferenceModel,
        isSelected: Bool,
        sendAction: @escaping DefaultConnectionFeature.ActionSender
    ) {
        self.model = model
        self.isSelected = isSelected
        self.sendAction = sendAction
    }

    public var body: some View {
        Button {
            sendAction(.preferenceSelected(model.preference))
        } label: {
            content
        }
        .buttonStyle(RecentRowButtonStyle())
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 12) {
            LocationFeatureView(model: model.locationFeatureModel)
            Spacer()
            Accessory(style: .checkmark(isActive: isSelected), size: .large)
        }
        .padding(.horizontal, .themeSpacing16)
        .frame(maxWidth: .infinity, minHeight: Self.itemCellHeight)
    }
}
