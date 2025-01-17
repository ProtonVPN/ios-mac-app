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
                Spacer()
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
                }
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                Asset.widgetBackground.swiftUIColor
                gradientColor(for: entry)
            }
        }

    }
}

// MARK: - Private helpers

private func gradientColor(for entry: ConnectWidgetEntry) -> LinearGradient {

    guard entry.signedIn else {
        return .linearGradient(stops: [.init(color: Asset.widgetLoggedOutGradientStart.swiftUIColor, location: 0),
                                       .init(color: Asset.widgetLoggedOutGradientStop.swiftUIColor, location: 0.7)],
                               startPoint: .topTrailing,
                               endPoint: .bottomLeading)
    }

    let startColor: Color
    switch entry.protectionState {
    case .protected:
        startColor = Asset.widgetStatusProtected.swiftUIColor
    case .unprotected:
        startColor = Asset.widgetStatusUnprotected.swiftUIColor
    case .protecting:
        startColor = Asset.widgetStatusProtecting.swiftUIColor
    }

    return .linearGradient(stops: [.init(color: startColor, location: 0),
                                   .init(color: .clear, location: 0.5)],
                           startPoint: .top,
                           endPoint: .bottom)
}
