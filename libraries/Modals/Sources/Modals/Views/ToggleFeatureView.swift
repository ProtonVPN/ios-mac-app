//
//  Created on 16/10/2024.
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

#if os(iOS)
// For now, iOS only but it needs just a few tweaks to be macOS compatible so keeping it here.
import SwiftUI
import Theme

public struct ToggleFeatureView: View {
    let title: String
    let subtitle: String
    let onToggleUpdate: (Bool) -> Void

    @State private var toggleIsOn: Bool

    public init(
        title: String,
        subtitle: String,
        initialState: Bool,
        onToggleUpdate: @escaping (Bool) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.toggleIsOn = initialState
        self.onToggleUpdate = onToggleUpdate
    }

    public var body: some View {
        HStack(alignment: .top, spacing: .themeSpacing8) {
            VStack(alignment: .leading) {
                Text(title)
                    .themeFont(.body2(emphasised: false))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .themeFont(.overline(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: $toggleIsOn) {
                Text("Toggle Label")
            }
            .labelsHidden()
            .tint(Theme.Asset.onboardingTint.swiftUIColor)
        }
        .onChange(of: toggleIsOn, perform: onToggleUpdate)
        .padding(.themeSpacing16)
    }
}

#Preview {
    ToggleFeatureView(
        title: "Share anonymous usage statistics",
        subtitle: "Usage data helps us overcome VPN blocks and improve app performance.",
        initialState: true,
        onToggleUpdate: { _ in () }
    )
}
#endif
