//
//  Created on 24/07/2025 by Max Kupetskyi.
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

import ComposableArchitecture
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

public struct NATPMPPortView: View {
    @Perception.Bindable var store: StoreOf<NATPMPFeature>

    public init() {
        let store = Store(initialState: .loading) {
            NATPMPFeature()
        }
        self.init(store: store)
    }

    public init(store: StoreOf<NATPMPFeature>) {
        self.store = store
    }

    public var body: some View {
        switch store.state {
        case .loading:
            LoadingPortView()
                .onAppear {
                    store.send(.startPortMapping)
                }
        case let .loaded(externalPortNumber, updateDate):
            ActivePortView(
                portNumber: externalPortNumber,
                updateDate: updateDate
            )
        // will not be used
        case .error:
            EmptyView()
        }
    }
}

// MARK: - Active Port View

struct ActivePortView: View {
    let portNumber: UInt16
    let updateDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing12) {
            // Header with status indicator
            Text(Localizable.pfActivePortNumber)
                .foregroundColor(Color(.text, .weak))
                .themeFont(.callout(emphasised: true))

            // Port number with copy button
            HStack(alignment: .firstTextBaseline, spacing: .themeSpacing8) {
                // Green status indicator
                Asset.pfIndicator.swiftUIImage
                    .resizable()
                    .frame(.square(.themeSpacing16))

                VStack(alignment: .leading, spacing: .themeSpacing8) {
                    HStack(spacing: .themeSpacing4) {
                        Text(String(portNumber))
                            .foregroundColor(Color(.text))
                            .font(.title2(emphasised: false))

                        Button(action: {
                            copyPortNumber(portNumber)
                        }) {
                            IconProvider.squares
                                .resizable()
                                .frame(.square(.themeSpacing16))
                        }
                        .buttonStyle(.plain)
                        .help(Localizable.pfCopyPortNumber)

                        Spacer()
                    }
                    HStack {
                        // Update timestamp
                        Text(formatUpdateTime(updateDate))
                            .foregroundColor(Color(.text, .weak))
                            .themeFont(.callout(emphasised: false))
                        Spacer()
                    }
                }
            }
        }
        .padding(.themeSpacing16)
        .background(Color(.background, .weak))
        .cornerRadius(.themeRadius8)
    }

    // MARK: - Sate

    private static let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    private func formatUpdateTime(_ date: Date) -> String {
        @Dependency(\.date.now) var now
        let timeAgo = Self.relativeDateTimeFormatter.localizedString(for: date, relativeTo: now)
        return Localizable.pfUpdated(timeAgo)
    }
}

// MARK: - Loading Port View

struct LoadingPortView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                Text(Localizable.pfActivePortNumber)
                    .foregroundColor(Color(.text, .weak))
                    .themeFont(.callout(emphasised: true))

                HStack(spacing: .themeSpacing8) {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text(Localizable.pfLoading)
                        .foregroundColor(Color(.text))
                        .font(.title2(emphasised: false))
                }
            }
            Spacer()
        }
        .padding(.themeSpacing16)
        .background(Color(.background, .weak))
        .cornerRadius(.themeRadius8)
    }
}

// MARK: - Status Port View

struct StatusPortView: View {
    let portNumber: UInt16

    var body: some View {
        HStack(spacing: .themeSpacing4) {
            Text(Localizable.pfActivePortStatus)
                .foregroundColor(Color(.text))
                .themeFont(.callout(emphasised: true))

            Asset.pfIndicator.swiftUIImage
                .resizable()
                .frame(.square(.themeSpacing12))

            Text(String(portNumber))
                .foregroundColor(Color(.text))
                .font(.title3(emphasised: false))

            Button(action: {
                copyPortNumber(portNumber)
            }) {
                IconProvider.squares
                    .resizable()
                    .frame(.square(.themeSpacing12))
            }
            .buttonStyle(.plain)
            .help(Localizable.pfCopyPortNumber)
        }
        .padding(.themeSpacing16)
        .background(Color(.background, .weak))
        .cornerRadius(.themeRadius8)
    }
}

private func copyPortNumber(_ portNumber: UInt16) {
    let portString = String(portNumber)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(portString, forType: .string)
}

// MARK: - Preview

#if DEBUG
    #Preview {
        VStack(spacing: 16) {
            // Active state
            ActivePortView(
                portNumber: 36528,
                updateDate: Date().addingTimeInterval(-35 * 60) // 35 minutes ago
            )

            // Loading state
            LoadingPortView()

            // Status view
            StatusPortView(portNumber: 36528)
        }
        .padding()
        .background(Color(.background))
    }
#endif
