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

#if DEBUG
    import ComposableArchitecture
    import Domain
    import SettingsShared
    import SwiftUI
    import Theme

    struct KeychainDebugView: View {
        @Binding var store: StoreOf<KeychainDebugFeature>

        var body: some View {
            content
                .padding()
                .navigationTitle("Keychain")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            store.send(.clearKeychainsTapped)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .refreshable { store.send(.loadKeychainData) }
                .alert($store.scope(state: \.alert, action: \.alert))
        }

        @ViewBuilder
        private var content: some View {
            switch store.content {
            case .none:
                ProgressView()
                    .task { store.send(.loadKeychainData) }

            case .loading:
                ProgressView()

            case let .loaded(data):
                Form {
                    Section {
                        authKeychainCell(data: data.authKeychainData)
                    } header: {
                        Text("Auth Keychain")
                    }
                    Section {
                        authKeychainCell(data: data.unauthKeychainData)
                    } header: {
                        Text("Unauth Keychain")
                    }
                    Section {
                        vpnKeysCell(keys: data.vpnAuthKeychainData.keys)
                        certificateCell(certificate: data.vpnAuthKeychainData.certificate)
                    } header: {
                        Text("VPN Authentication Keychain")
                    } footer: {
                        Text("Tap on any value to copy it to the clipboard.")
                    }
                }

            case let .failed(error):
                HStack(alignment: .center) {
                    VStack(alignment: .center, spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                            .multilineTextAlignment(.center)
                    }.padding(.horizontal, 100)
                }
            }
        }

        @ViewBuilder
        private func authKeychainCell(data: KeychainDebugFeature.AuthKeychainData?) -> some View {
            if let data {
                VStack(alignment: .leading) {
                    Text("Username")
                    copyableText(data.username)

                    Divider()

                    Text("Access Token")
                    copyableText(data.accessToken)

                    Divider()

                    Text("Refresh Token")
                    copyableText(data.refreshToken)

                    Divider()

                    Text("Session ID")
                    copyableText(data.sessionId)

                    Divider()

                    Text("User ID")
                    copyableText(data.userId ?? "—")

                    Divider()

                    Text("Scopes")
                    copyableText(data.scopes.isEmpty ? "—" : data.scopes.joined(separator: ", "))
                }
            } else {
                HStack {
                    Text("No Data")
                    Spacer()
                    Image(systemName: "nosign")
                }
            }
        }

        @ViewBuilder
        private func vpnKeysCell(keys: KeychainDebugFeature.VPNAuthKeychainData.Keys?) -> some View {
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

        @ViewBuilder
        private func certificateCell(certificate: KeychainDebugFeature.VPNAuthKeychainData.Certificate?) -> some View {
            if let certificate {
                VStack(alignment: .leading) {
                    Text("Certificate")
                    copyableText(certificate.pem)

                    Divider()

                    Text("Expiry")
                    copyableText(certificate.expiry.formatted())

                    Divider()

                    featuresCell(features: certificate.features)
                }
            } else {
                HStack {
                    Text("No Certificate")
                    Spacer()
                    Image(systemName: "nosign")
                }
            }
        }

        @ViewBuilder
        private func featuresCell(features: VPNConnectionFeatures?) -> some View {
            if let features {
                VStack(alignment: .leading) {
                    Text("Certificate Features")
                    Divider()
                    FeaturesView(features: features)
                }

            } else {
                HStack {
                    Text("Features")
                    Spacer()
                    Image(systemName: "nosign")
                }
            }
        }

        @ViewBuilder
        private func cell(title: String, value: String) -> some View {
            Text(title)
                .styled(.disabled)
            copyableText(value)
        }

        private func copyableText(_ value: String) -> some View {
            Text(value)
                .onTapGesture { UIPasteboard.general.string = value }
        }
    }

    struct FeaturesView: View {
        private let features: VPNConnectionFeatures

        init(features: VPNConnectionFeatures) {
            self.features = features
        }

        var body: some View {
            VStack {
                row(key: "NetShield", value: "\(optional: NetShieldType(rawValue: features.netshield.rawValue))")
                row(key: "VPN Accelerator", value: "\(features.vpnAccelerator)")
                row(key: "Moderate NAT", value: "\(optional: NATType(rawValue: features.natType.rawValue))")
                row(key: "Safe Mode", value: "\(optional: features.safeMode)")
            }
        }

        private func row(key: String, value: String) -> some View {
            HStack {
                Text(key)
                Spacer()
                Text(value)
            }
        }
    }
#endif
