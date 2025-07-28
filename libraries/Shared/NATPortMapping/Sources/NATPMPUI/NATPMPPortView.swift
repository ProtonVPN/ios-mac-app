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
import SwiftUI
import Theme

public struct NATPMPPortView: View {
    @Perception.Bindable var store: StoreOf<NATPMPFeature>

    public init(store: StoreOf<NATPMPFeature>) {
        self.store = store
    }

    public var body: some View {
        WithPerceptionTracking {
            if let portNumber = store.externalPortNumber {
                ActivePortView(
                    portNumber: portNumber,
                    updateDate: store.updateDate
                )
            } else if store.isLoading {
                LoadingPortView()
            } else {
                // will not be used
                EmptyView()
            }
        }
    }
}

// MARK: - Active Port View

private struct ActivePortView: View {
    let portNumber: UInt16
    let updateDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with status indicator
            Text("Active port number")
                .foregroundColor(Color(.text))
                .themeFont(.callout(emphasised: true))

            // Port number with copy button
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.spacing8.rawValue) {
                // Green status indicator
                Image("pf_indicator", bundle: .module)
                    .resizable()
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.spacing8.rawValue) {
                    HStack(spacing: AppTheme.Spacing.spacing4.rawValue) {
                        Text("\(String(portNumber))")
                            .foregroundColor(Color(.text))
                            .font(.system(size: 18, weight: .semibold))

                        Button(action: {
                            copyPortNumber()
                        }) {
                            IconProvider.squares
                                .resizable()
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                        .help("Copy port number")

                        Spacer()
                    }
                    HStack {
                        // Update timestamp
                        if let updateDate {
                            Text(formatUpdateTime(updateDate))
                                .foregroundColor(Color(.text, .weak))
                                .themeFont(.callout(emphasised: false))
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.background, .weak))
        .cornerRadius(8)
    }

    private func copyPortNumber() {
        let portString = String(portNumber)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(portString, forType: .string)
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
        return "Updated \(timeAgo)"
    }
}

// MARK: - Loading Port View

private struct LoadingPortView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.spacing8.rawValue) {
            Text("Active port number")
                .foregroundColor(Color(.text))
                .themeFont(.callout(emphasised: true))

            HStack(spacing: AppTheme.Spacing.spacing8.rawValue) {
                ProgressView()
                    .scaleEffect(0.8)

                Text("Loading...")
                    .foregroundColor(Color(.text))
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .padding(16)
        .background(Color(.background, .weak))
        .cornerRadius(8)
    }
}

// MARK: - Status Port View

private struct StatusPortView: View {
    let portNumber: UInt16

    var body: some View {
        HStack(spacing: AppTheme.Spacing.spacing4.rawValue) {
            Text("Active port:")
                .foregroundColor(Color(.text))
                .themeFont(.callout(emphasised: true))

            Image("pf_indicator", bundle: .module)
                .resizable()
                .frame(width: 12, height: 12)

            Text("\(String(portNumber))")
                .foregroundColor(Color(.text))
                .font(.system(size: 14, weight: .medium))

            Button(action: {
                copyPortNumber()
            }) {
                IconProvider.squares
                    .resizable()
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .help("Copy port number")
        }
        .padding(16)
        .background(Color(.background, .weak))
        .cornerRadius(8)
    }

    private func copyPortNumber() {
        let portString = String(portNumber)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(portString, forType: .string)
    }
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
