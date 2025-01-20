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

    public var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                if !entry.signedIn {
                    UnauthenticatedView()
                } else {
                    header(entry, widgetFamily: widgetFamily)
                    Spacer()
                    serverInfo(entry, widgetFamily: widgetFamily)
                    VStack(spacing: .themeSpacing16) {
                        buttons(entry, widgetFamily: widgetFamily)
                        recents(entry, widgetFamily: widgetFamily, geometry: geometry)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                ZStack {
                    Color(.background)
                    gradientColor(for: entry)
                }
            }
        }
    }
}

// MARK: - Subviews

private func header(_ entry: ConnectWidgetEntry, widgetFamily: WidgetFamily) -> some View {
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
                    if let location = entry.connectionSpec?.location, location.subtext(locale: .current) != nil, widgetFamily == .systemMedium {
                        FlagView(location: location, flagSize: .defaultSize)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        IconProvider.lockFilled
                        Text(Localizable.connectionStatusProtected)
                            .font(.body3(emphasised: true))
                    }
                    .foregroundStyle(Color(.icon, .vpnGreen))
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
            case .protecting:
                Text(Localizable.connecting)
                    .font(.body3(emphasised: true))
                    .foregroundStyle(Color(.text, .normal))
            case .unprotected:
                Group {
                    IconProvider.lockOpenFilled2
                    Text(Localizable.connectionStatusUnprotected)
                        .font(.body3(emphasised: true))
                }
                .foregroundStyle(ColorProvider.NotificationError)
            }
        }
    }
    .frame(maxWidth: .infinity, idealHeight: 40)
}

private func serverInfo(_ entry: ConnectWidgetEntry, widgetFamily: WidgetFamily) -> some View {
    Group {
        if !(widgetFamily == .systemMedium && entry.protectionState == .unprotected), let location = entry.connectionSpec?.location {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                if widgetFamily != .systemSmall && (widgetFamily != .systemMedium || location.subtext(locale: .current) == nil) {
                    FlagView(location: location, flagSize: .defaultSize)
                }
                VStack(alignment: .leading) {
                    if let headerText = location.headerText(locale: .current) {
                        Text(headerText)
                            .themeFont(.caption(emphasised: true))
                            .foregroundStyle(Color(.text, .normal))
                    }
                    if let subtext = location.subtext(locale: .current) {
                        Text(subtext)
                            .themeFont(.overline(emphasised: false))
                            .foregroundStyle(Color(.text, .weak))
                    }
                }
            }
            Spacer()
        }
    }
}

private func recents(_ entry: ConnectWidgetEntry, widgetFamily: WidgetFamily, geometry: GeometryProxy) -> some View {
    Group {
        let itemWidth = geometry.size.width / 3 - .themeSpacing6
        if widgetFamily == .systemMedium && entry.protectionState == .unprotected || widgetFamily == .systemLarge && entry.recentServers.count > 0 {
            LazyHGrid(rows: [GridItem(.fixed(itemWidth))], spacing: .themeSpacing8) {
                ForEach(entry.recentServers, id: \.self) { recentConnection in
                    Button(intent: ConnectToVPNIntent()) { // TODO: Send the recentConnection as parameter to the AppIntent.
                        VStack(alignment: .leading) {
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(recentConnection.underMaintenance)
                    .padding(.themeSpacing8)
                    .frame(width: itemWidth, height: 90, alignment: .leading)
                    .background(Color(.background, .weak))
                    .clipRectangle(cornerRadius: .radius12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func buttons(_ entry: ConnectWidgetEntry, widgetFamily: WidgetFamily) -> some View {
    Group {
        switch entry.protectionState {
        case .protected:
            Button(intent: DisconnectFromVPNIntent()) {
                Text(Localizable.disconnect)
            }
            .buttonStyle(SecondaryButtonStyle())
        case .protecting:
            Button(intent: DisconnectFromVPNIntent()) { // TODO: have another app intent for cancellation.
                Text(Localizable.cancel)
            }
            .buttonStyle(SecondaryButtonStyle())
        case .unprotected:
            if widgetFamily != .systemMedium {
                Button(intent: ConnectToVPNIntent()) {
                    Text(Localizable.connect)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Private helpers

private func gradientColor(for entry: ConnectWidgetEntry) -> LinearGradient {

    guard entry.signedIn else {
        return .linearGradient(stops: [.init(color: Color(.loggedOutGradientStart), location: 0),
                                       .init(color: Color(.loggedOutGradientStop), location: 0.7)],
                               startPoint: .topTrailing,
                               endPoint: .bottomLeading)
    }

    let startColor: Color
    switch entry.protectionState {
    case .protected:
        startColor = Color(.statusProtected)
    case .unprotected:
        startColor = Color(.statusUnprotected)
    case .protecting:
        startColor = Color(.statusProtecting)
    }

    return .linearGradient(stops: [.init(color: startColor, location: 0),
                                   .init(color: .clear, location: 1)],
                           startPoint: .top,
                           endPoint: .center)
}
