//
//  Created on 2025-01-15.
//
//  Copyright (c) 2025 Proton AG
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
import WidgetKit
import VPNAppCore
import Theme
import Strings
import ProtonCoreUIFoundations
import Domain
import SharedViews

import ComposableArchitecture

public struct ConnectWidgetView : View {
    let entry: ConnectWidgetEntry

    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.widgetRenderingMode) var renderingMode

    public var body: some View {
        if case .accented = renderingMode {
            content
                .luminanceToAlpha()
        } else {
            content
        }
    }

    @ViewBuilder
    var content: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                if entry.protectionState == .signedOut {
                    UnauthenticatedView()
                } else {
                    HeaderView(entry: entry)
                    Spacer()
                    ServerInfoView(entry: entry)
                    VStack(spacing: .themeSpacing16) {
                        ButtonsView(entry: entry)
                        if (widgetFamily == .systemLarge) {
                            RecentsView(entry: entry, geometry: geometry)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                ZStack {
                    Color(.background)
                    LinearGradient.forProtectionState(entry.protectionState)
                }
                .environment(\.colorScheme, .dark) // we need both colorScheme overrides because of the `containerBackground(for: .widget)`
            }
        }
        .environment(\.colorScheme, .dark) // we need both colorScheme overrides because of the `containerBackground(for: .widget)`
    }
}

// MARK: - Subviews

private struct HeaderView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: ConnectWidgetEntry

    var body: some View {
        HStack(alignment: .center) {
            if widgetFamily == .systemSmall {
                // We show server flag if available
                if let location = entry.connectionSpec?.location {
                    FlagView(location: location, flagSize: .defaultSize)
                    Spacer()
                }
            } else {
                switch entry.protectionState {
                case .protected:
                    ZStack(alignment: .leading) {
                        if let location = entry.connectionSpec?.location, widgetFamily == .systemSmall {
                            FlagView(location: location, flagSize: .defaultSize)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack {
                            IconProvider.lockFilled
                            Text(Localizable.connectionStatusProtected)
                                .font(.body2(emphasised: true))
                                .offset(y: 2)
                        }
                        .foregroundStyle(Color(.icon, .vpnGreen))
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                case .protecting:
                    Text(Localizable.connecting)
                        .font(.body2(emphasised: true))
                        .foregroundStyle(Color(.text, .normal))
                case .unprotected:
                    Group {
                        IconProvider.lockOpenFilled2
                        Text(Localizable.widgetUnprotectedHeader)
                            .font(.body2(emphasised: true))
                            .offset(y: 2)
                    }
                    .foregroundStyle(Color(.text, .danger))
                case .signedOut:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, idealHeight: 40)
    }
}

private struct ServerInfoView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: ConnectWidgetEntry

    var body: some View {
        Group {
            if let location = entry.connectionSpec?.location {
                HStack(alignment: .top, spacing: .themeSpacing12) {
                    if widgetFamily != .systemSmall {
                        FlagView(location: location, flagSize: .defaultSize)
                    }
                    VStack(alignment: .leading, spacing: .zero) {
                        if let headerText = location.headerText(locale: .current) {
                            Text(headerText)
                                .themeFont(widgetFamily == .systemLarge ? .body1(.semibold) : .body2(emphasised: true))
                                .foregroundStyle(Color(.text, .normal))
                        }
                        if let subtext = location.subtext(locale: .current) {
                            Text(subtext)
                                .themeFont(widgetFamily == .systemLarge ? .body2(emphasised: false) : .caption(emphasised: false))
                                .foregroundStyle(Color(.text, .weak))
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

private struct RecentsView: View {
    private static let recentsHeight: CGFloat = 90

    @Environment(\.widgetFamily) var widgetFamily
    let entry: ConnectWidgetEntry
    let geometry: GeometryProxy
    var itemWidth: CGFloat {
        (geometry.size.width - 2 * .themeSpacing8) / 3
    }

    private var emptyRecentsView: some View {
        HStack(alignment: .center) {
            VStack {
                Text(Localizable.widgetRecentsTitle)
                    .themeFont(.caption(emphasised: true))
                Text(Localizable.widgetRecentsDescription)
                    .themeFont(.caption(emphasised: false))
            }
            .foregroundStyle(Color(.text, .weak))
            .frame(maxWidth: .infinity)
        }
        .frame(height: Self.recentsHeight)
        .background(Color(.background, .weak))
        .clipRectangle(cornerRadius: .radius12)
    }

    private func recentItem(index: Int, recentConnection: RecentConnection) -> some View {
        let location = recentConnection.connection.location
        return Button(intent: ConnectToVPNIntent(recentIndex: index)) {
            VStack(alignment: .center, spacing: .themeSpacing8) {
                if recentConnection.underMaintenance {
                    IconProvider.wrench
                        .foregroundStyle(Color(.icon, .weak))
                } else {
                    FlagView(location: location, flagSize: .widgetRecentsSize)
                }
                VStack(spacing: .themeSpacing2) {
                    if let headerText = location.headerText(locale: .current) {
                        Text(headerText)
                            .themeFont(.caption(emphasised: true))
                            .foregroundStyle(Color(.text, .normal))
                    }
                    if let subtext = location.subtext(locale: .current) {
                        Text(subtext)
                            .themeFont(.overline(emphasised: false))
                            .foregroundStyle(Color(.text, .weak))
                            .lineLimit(1)
                    }
                }
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, .themeSpacing8)
            .frame(width: itemWidth, height: Self.recentsHeight)
            .background(Color(.background, .weak))
            .clipRectangle(cornerRadius: .radius12)
        }
        .buttonStyle(PlainPressedButtonStyle())
    }

    private var populatedRecentsView: some View {
        VStack(alignment: .leading, spacing: .themeSpacing12) {
            Text(Localizable.widgetRecentsTitle)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color(.text, .weak))

            LazyHGrid(rows: [GridItem(.fixed(itemWidth))], spacing: .themeSpacing8) {
                ForEach(Array(entry.recentServers.prefix(3).enumerated()),
                        id: \.offset,
                        content: recentItem)
            }
            .frame(height: Self.recentsHeight)
        }
        .lineSpacing(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        if entry.recentServers.isEmpty {
            emptyRecentsView
        } else {
            populatedRecentsView
        }
    }
}

private struct ButtonsView : View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: ConnectWidgetEntry

    var body: some View {
        switch entry.protectionState {
        case .protected:
            Button(intent: DisconnectFromVPNIntent()) {
                Text(Localizable.disconnect)
            }
            .buttonStyle(SecondaryButtonStyle())
        case .protecting:
            Button(intent: DisconnectFromVPNIntent()) {
                Text(Localizable.cancel)
            }
            .buttonStyle(SecondaryButtonStyle())
        case .unprotected:
            Button(intent: ConnectToVPNIntent()) {
                Text(Localizable.connect)
            }
            .buttonStyle(PrimaryButtonStyle())
        case .signedOut:
            EmptyView()
        }
    }
}
