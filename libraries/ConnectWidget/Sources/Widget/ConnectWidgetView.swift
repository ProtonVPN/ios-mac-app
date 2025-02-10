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

    public var body: some View {
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
                        RecentsView(entry: entry, geometry: geometry)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                ZStack {
                    Color(.background)
                    linearGradient(for: entry)
                }
            }
        }
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
                        Text(Localizable.connectionStatusUnprotected)
                            .font(.body2(emphasised: true))
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
                HStack(alignment: .top, spacing: .themeSpacing8) {
                    if widgetFamily != .systemSmall {
                        FlagView(location: location, flagSize: .defaultSize)
                    }
                    VStack(alignment: .leading) {
                        if let headerText = location.headerText(locale: .current) {
                            Text(headerText)
                                .themeFont(widgetFamily == .systemLarge ? .body1(.semibold) : .caption(emphasised: true))
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

    var body: some View {
        Group {
            let itemWidth = (geometry.size.width - 2 * .themeSpacing8) / 3
            if (widgetFamily == .systemLarge) {
                if entry.recentServers.isEmpty {
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
                } else {
                    VStack(alignment: .leading, spacing: .themeSpacing12) {
                        if widgetFamily == .systemLarge {
                            Text(Localizable.widgetRecentsTitle)
                                .themeFont(.caption(emphasised: false))
                                .foregroundStyle(Color(.text, .weak))
                        }
                        LazyHGrid(rows: [GridItem(.fixed(itemWidth))], spacing: .themeSpacing8) {
                            ForEach(entry.recentServers.prefix(3), id: \.self) { recentConnection in
                                Button(intent: ConnectToVPNIntent()) { // TODO: VPNAPPL-2467 - Send the recentConnection as parameter to the AppIntent.
                                    VStack(alignment: .center) {
                                        if recentConnection.underMaintenance {
                                            IconProvider.wrench
                                        } else {
                                            FlagView(location: recentConnection.connection.location, flagSize: .defaultSize)
                                        }
                                        if let headerText = recentConnection.connection.location.headerText(locale: .current) {
                                            Text(headerText)
                                                .themeFont(.caption(emphasised: true))
                                                .foregroundStyle(Color(.text, .normal))
                                        }
                                        if let subtext = recentConnection.connection.location.subtext(locale: .current) {
                                            Text(subtext)
                                                .themeFont(.overline(emphasised: false))
                                                .foregroundStyle(Color(.text, .weak))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.themeSpacing8)
                                .frame(width: itemWidth, height: Self.recentsHeight, alignment: .leading)
                                .background(Color(.background, [.interactive, .weak]))
                                .clipRectangle(cornerRadius: .radius12)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct ButtonsView : View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: ConnectWidgetEntry

    var body: some View
    {
        Group {
            switch entry.protectionState {
            case .protected:
                Button(intent: DisconnectFromVPNIntent()) {
                    Text(Localizable.disconnect)
                }
                .buttonStyle(SecondaryButtonStyle())
            case .protecting:
                Button(intent: DisconnectFromVPNIntent()) { // TODO: VPNAPPL-2629 - define another app intent for cancellation.
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
}

// MARK: - Private helpers

private func linearGradient(for entry: ConnectWidgetEntry) -> LinearGradient {
    let startColor: Color
    switch entry.protectionState {
    case .signedOut:
        return .linearGradient(stops: [.init(color: Color(.loggedOutGradientStart), location: 0),
                                       .init(color: Color(.loggedOutGradientStop), location: 0.7)],
                               startPoint: .topTrailing,
                               endPoint: .bottomLeading)
    case .protected:
        startColor = Color(.icon, .vpnGreen)
    case .unprotected:
        startColor = Color(.background, .danger)
    case .protecting:
        startColor = .white
    }

    return .linearGradient(stops: [.init(color: startColor.opacity(0.5), location: 0),
                                   .init(color: .clear, location: 1)],
                           startPoint: .top,
                           endPoint: .center)
}
