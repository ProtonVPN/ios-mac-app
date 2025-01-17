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

import ComposableArchitecture

/// TODO: Revamp this view [VPNAPPL-2591]
public struct ConnectWidgetView : View {

    let entry: ConnectWidgetEntry

    @Environment(\.widgetFamily) var widgetFamily

    public var body: some View {
        VStack {
            if !entry.signedIn {
                UnauthenticatedView()
            } else {
                header(entry, widgetFamily: widgetFamily)
                Spacer()
                buttons(entry, widgetFamily: widgetFamily)
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                Color(.background)
                gradientColor(for: entry)
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
                                   .init(color: .clear, location: 0.5)],
                           startPoint: .top,
                           endPoint: .bottom)
}

// MARK: - Subviews
private func header(_ entry: ConnectWidgetEntry, widgetFamily: WidgetFamily) -> some View {
    Group {
        if widgetFamily == .systemSmall {
            EmptyView()
        } else {
            HStack(alignment: .center) {
                switch entry.protectionState {
                case .protected:
                    Group {
                        IconProvider.lockFilled
                        Text(Localizable.connectionStatusProtected)
                            .font(.body3(emphasised: true))
                    }
                    .foregroundStyle(Color(.icon, .vpnGreen))
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
            switch widgetFamily {
            case .systemMedium: // In medium-sized widgets, we display recent items instead of the connect button.
                EmptyView()
            default:
                Button(intent: ConnectToVPNIntent()) {
                    Text(Localizable.connect)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

