//
//  Created on 27/03/2025 by Chris Janusiewicz.
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
import ComposableArchitecture
import SettingsShared

struct KeychainDebugView: View {
    @Binding var store: StoreOf<KeychainDebugFeature>

    var body: some View {
        WithPerceptionTracking {
            content
                .padding()
                .navigationTitle("Keychain")
                .refreshable { store.send(.loadKeychainData) }
                .alert($store.scope(state: \.alert, action: \.alert))
        }
    }

    @ViewBuilder private var content: some View {
        switch store.content {
        case .none:
            ProgressView()
                .task { store.send(.loadKeychainData) }

        case .loading:
            ProgressView()

        case .loaded(let data):
            Form {
                Section("VPN Authentication Keychain") {
                    vpnKeysCell(keys: data.keys)
                    certificateCell(certificate: data.certificate)
                }
            }
            Text("Tap on any value to copy it to the clipboard.")
                .styled(.hint)
                .padding(.all)

        case .failed(let error):
            HStack(alignment: .center) {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                        .multilineTextAlignment(.center)
                }.padding(.horizontal, 100)
            }
        }
    }

    @ViewBuilder private func vpnKeysCell(keys: KeychainDebugFeature.State.AuthKeychainData.Keys?) -> some View {
        if let keys {
            VStack(alignment: .leading) {
                HStack {
                    Text("Private Key")
                    Spacer()
                    Button {
                        store.send(.generateNewKeysTapped)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                copyableText(keys.privateKey)

                Divider()

                Text("Public Key")
                copyableText(keys.publicKey)
            }
        } else {
            HStack {
                Text("No VPN Keys")
                Spacer()
                Image(systemName: "nosign")
            }
        }
    }

    @ViewBuilder private func certificateCell(certificate: KeychainDebugFeature.State.AuthKeychainData.Certificate?) -> some View {
        if let certificate {
            VStack(alignment: .leading) {
                Text("Certificate")
                copyableText(certificate.pem)

                Divider()

                Text("Expiry")
                copyableText(certificate.expiry.formatted())
            }
        } else {
            HStack {
                Text("No Certificate")
                Spacer()
                Image(systemName: "nosign")
            }
        }
    }

    @ViewBuilder private func cell(title: String, value: String) -> some View {
        Text(title)
            .styled(.disabled)
        copyableText(value)
    }

    private func copyableText(_ value: String) -> some View {
        Text(value)
            .onTapGesture { UIPasteboard.general.string = value }
    }
}
