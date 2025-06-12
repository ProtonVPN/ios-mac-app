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
import ConnectionDetailsShared
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

    private var ipAddressTuple: (value: String, accessibilityValue: String) {
        let isLocalIpHidden = store.localIpHidden
        if isLocalIpHidden {
            let localizedAction = isLocalIpHidden ?
                Localizable.connectionDetailsAccessibilityIpViewShowAddress :
                Localizable.connectionDetailsAccessibilityIpViewHideAddress
            return ("***.***.***.***", localizedAction)
        } else {
            let value = store.userIP ?? Localizable.connectionDetailsIpviewIpUnavailable
            return (value, value)
        }
    }

    public var body: some View {
        WithPerceptionTracking {
            HStack {
                VStack {
                    HStack(spacing: buttonSpacing) {
                        Text(Localizable.connectionDetailsIpviewIpMy)
                            .foregroundColor(Color(.text, .weak))
                        
                        if store.buttonIsVisible {
                            Button {
                                store.send(.changeIPVisibility)
                            } label: {
                                (store.localIpHidden
                                 ? IconProvider.eye
                                 : IconProvider.eyeSlash)
                                .resizable().frame(width: buttonSize, height: buttonSize)
                                .foregroundColor(Color(.text, .weak))
                            }
                        }
                    }
                    .frame(minHeight: minTopHeight)

                    Text(ipAddressTuple.value)
                        .foregroundColor(Color(.text, .normal))
                        .accessibilityElement()
                        .accessibilityValue(ipAddressTuple.accessibilityValue)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAction {
                    store.send(.changeIPVisibility)
                }
                .frame(maxWidth: .infinity) // Makes both sides equal width
                
                IconProvider.arrowRight
                    .accessibilityHidden(true)
                    .foregroundColor(Color(.text, .weak))
                
                VStack {
                    Text(Localizable.connectionDetailsIpviewIpVpn)
                        .foregroundColor(Color(.text, .weak))
                        .frame(minHeight: minTopHeight)

                    let vpnIpAddressValue = store.vpnIp ?? Localizable.connectionDetailsIpviewIpUnavailable

                    Text(vpnIpAddressValue)
                        .foregroundColor(Color(.text, .normal))
                        .accessibilityElement()
                        .accessibilityValue(vpnIpAddressValue)
                }
                .accessibilityElement(children: .combine)
                .frame(maxWidth: .infinity) // Makes both sides equal width
            }
            .padding(.vertical, .themeSpacing12)
            .padding(.horizontal, .themeSpacing16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: .themeRadius12)
                .fill(Color(.background, .normal)))
        }
    }
}

// MARK: - Previews

#Preview {
    @Shared(.userIP) var userIP: String?
    $userIP.withLock { $0 = "127.0.0.1" }

    return IPView(store: .init(initialState: .init(), reducer: { IPViewFeature() }))
        .colorScheme(.dark)
}
