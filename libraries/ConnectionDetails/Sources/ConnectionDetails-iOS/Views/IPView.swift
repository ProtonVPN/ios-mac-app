//
//  Created on 2023-05-31.
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

    private let minTopHeight: CGFloat = 16
    @ScaledMetric var buttonSize: CGFloat = 16
    @ScaledMetric var buttonSpacing: CGFloat = 4

    public init(store: StoreOf<IPViewFeature>) {
        self.store = store
    }

    public var body: some View {
        HStack {
            WithViewStore(self.store, observe: { $0 }, content: { viewStore in
                VStack {
                    HStack(spacing: buttonSpacing) {
                        Text(Localizable.connectionDetailsIpviewIpMy)
                            .foregroundColor(Color(.text, .weak))

                        if viewStore.buttonIsVisible {
                            Button(action: {
                                viewStore.send(.changeIPVisibility)
                            }, label: {
                                (viewStore.localIpHidden
                                 ? IconProvider.eye
                                 : IconProvider.eyeSlash)
                                .resizable().frame(width: buttonSize, height: buttonSize)
                                .foregroundColor(Color(.text, .weak))
                            })
                        }
                    }
                    .frame(minHeight: minTopHeight)

                    Text(viewStore.localIpHidden ? "***************" : (viewStore.localIP ?? Localizable.connectionDetailsIpviewIpUnavailable ))
                        .foregroundColor(Color(.text, .normal))
                }
                .frame(maxWidth: .infinity) // Makes both sides equal width

            })

            IconProvider.arrowRight
                .foregroundColor(Color(.text, .weak))

            VStack {
                Text(Localizable.connectionDetailsIpviewIpVpn)
                    .foregroundColor(Color(.text, .weak))
                    .frame(minHeight: minTopHeight)

                WithViewStore(self.store, observe: { $0.vpnIp }, content: { viewStore in
                    Text(viewStore.state)
                        .foregroundColor(Color(.text, .normal))
                })
            }
            .frame(maxWidth: .infinity) // Makes both sides equal width
        }
        .padding([.top, .bottom], .themeSpacing12)
        .padding([.leading, .trailing], .themeSpacing16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: .themeRadius12)
            .fill(Color(.background, [.normal])))

    }
}

// MARK: - Previews

struct IPView_Previews: PreviewProvider {
    static var previews: some View {
        IPView(store: .init(initialState: .init(localIP: "127.0.0.1", vpnIp: "102.107.197.6"),
                            reducer: { IPViewFeature() }))
        .colorScheme(.dark)
    }
}
