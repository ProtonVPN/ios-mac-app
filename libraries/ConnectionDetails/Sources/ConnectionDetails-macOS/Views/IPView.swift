//
//  Created on 2023-06-02.
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
import ConnectionDetails
import ComposableArchitecture
import Strings
import ProtonCoreUIFoundations

public struct IPView: View {

    let store: StoreOf<IPViewFeature>

    @ScaledMetric var buttonSize: CGFloat = 16
    @ScaledMetric var buttonSpacing: CGFloat = 4
    private var verticalSpacing: CGFloat = .themeSpacing4

    public init(store: StoreOf<IPViewFeature>) {
        self.store = store
    }

    public var body: some View {
        HStack {
            VStack(spacing: verticalSpacing) {
                HStack(alignment: .center, spacing: buttonSpacing) {
                    Text(Localizable.connectionDetailsIpviewIpMy)
                        .foregroundColor(Color(.text, .weak))

                    Button(action: {
                        store.send(.changeIPVisibility)
                    }, label: {
                        (store.localIpHidden
                         ? IconProvider.eye
                         : IconProvider.eyeSlash)
                        .resizable().frame(width: buttonSize, height: buttonSize)
                        .foregroundColor(Color(.text, .weak))
                    })
                    .buttonStyle(PlainButtonStyle())

                }

                Text(store.localIpHidden ? "***.***.***.***.***" : (store.userIP ?? Localizable.connectionDetailsIpviewIpUnavailable ))
                    .foregroundColor(Color(.text, .normal))
            }
            .frame(maxWidth: .infinity) // Makes both sides equal width

            IconProvider.arrowRight
                .foregroundColor(Color(.text, .weak))

            VStack(spacing: verticalSpacing) {
                Text(Localizable.connectionDetailsIpviewIpVpn)
                    .foregroundColor(Color(.text, .weak))

//                Text(store.state) ??
//                    .foregroundColor(Color(.text, .normal))
            }
            .frame(maxWidth: .infinity) // Makes both sides equal width
        }
        .font(.body)
        .padding([.top, .bottom], .themeSpacing8)
        .padding([.leading, .trailing], .themeSpacing16)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: .themeRadius8)
                .stroke(Color(.border, .weak), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview {
    @Shared(.userIP) var userIP: String?
    userIP = "127.0.0.1"

    return IPView(store: Store(initialState: .init(), reducer: { IPViewFeature() }))
        .padding(16)
        .background(Color(.background))
        .colorScheme(.dark)
}
