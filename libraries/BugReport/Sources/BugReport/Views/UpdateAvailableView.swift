//
//  Created on 2022-02-02.
//
//  Copyright (c) 2022 Proton AG
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

struct UpdateAvailableView: View {

    @Binding var isActive: Bool

    @Environment(\.colors) var colors: Colors

    var body: some View {
        if isActive {
            updatevView
        } else {
            EmptyView()
        }
    }

    var updatevView: some View {
        VStack(spacing: 0) {

            #if os(iOS)
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1) // Prevents UpdateAvailableView's background bleeding on NavigationBar
            #endif

            HStack {
                Image(Asset.appIcon.name, bundle: Bundle.module)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Localizable.updateViewTitle)
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundColor(colors.textPrimary)

                    Text(Localizable.updateViewDescription)
                        .foregroundColor(colors.textSecondary)
                        .font(.system(size: 11))
                }

                Spacer()

                Button(Localizable.updateViewButton, action: { CurrentEnv.bugReportDelegate?.updateApp() })
                    .buttonStyle(UpdateButtonStyle())
                    .accessibilityIdentifier("Update app button")

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            #if os(iOS)
            .background(colors.backgroundWeak)
            #endif
        }
    }
}

struct UpdateAvailableView_Previews: PreviewProvider {
    @State private static var showUpdate = true

    static var previews: some View {
        Group {
            UpdateAvailableView(isActive: $showUpdate)
        }
    }
}
