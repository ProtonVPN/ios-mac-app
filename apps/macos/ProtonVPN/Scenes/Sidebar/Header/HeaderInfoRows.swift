//
//  Created on 11/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import Localization
import Strings
import SwiftUI
import Theme

/// The identifiers the macOS UI tests read the header's values from.
///
/// Each one sits on the `Text` holding the value rather than on the row around it. The tests match
/// `staticTexts[...]` and compare `value` against the protocol name or the address on its own, so a
/// row that also carries a load ring or a transfer rate would report the wrong string.
private enum AccessibilityIdentifiers {
    static let headerLabel = "headerLabel"
    static let ipLabel = "ipLabel"
    static let protocolLabel = "protocolLabel"
}

/// The headline: where the user is connected, or why they are not protected.
struct HeaderTitleView: View {
    let title: HeaderFeature.State.Title

    var body: some View {
        headline
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(AccessibilityIdentifiers.headerLabel)
    }

    @ViewBuilder
    private var headline: some View {
        switch title {
        case .authenticationRequired:
            text(Localizable.headerAuthRequired, style: .warning, bold: true)
        case .killSwitchActive:
            text(Localizable.killSwitchAdvancedBannerTitle, style: .warning, bold: true)
        case .unprotected:
            text(Localizable.youAreNotProtected, style: .danger, bold: true)
        case .unavailable:
            text(Localizable.noDescriptionAvailable, style: .normal, bold: false)
        case let .secureCore(entryCountryCode, exitCountryCode):
            HStack(spacing: 0) {
                icon(Theme.Asset.Icons.locks.swiftUIImage)
                text(" \(countryName(entryCountryCode)) ", style: .normal, bold: false)
                icon(Theme.Asset.Icons.chevronsRight.swiftUIImage)
                text(" \(countryName(exitCountryCode))", style: .normal, bold: false)
            }
            // Both country names read as one headline, the way every other case is a single Text.
            .accessibilityElement(children: .combine)
        case let .server(countryCode, name):
            text("\(countryName(countryCode)) \(name)", style: .normal, bold: false)
        }
    }

    private func text(_ value: String, style: AppTheme.Style, bold: Bool) -> Text {
        Text(value)
            .themeFont(.title2(emphasised: bold))
            .foregroundStyle(Color(.text, style))
    }

    private func icon(_ image: Image) -> some View {
        image
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(Color(.icon))
            .frame(.square(Dimensions.iconSize))
    }

    private func countryName(_ code: String) -> String {
        LocalizationUtility.default.countryName(forCode: code) ?? Localizable.unavailable
    }

    private enum Dimensions {
        static let iconSize: CGFloat = 16
    }
}

/// The exit address on the leading edge and the server's load on the trailing edge, or the message
/// explaining why traffic is not flowing.
struct HeaderAddressRow: View {
    let addressLine: HeaderFeature.State.AddressLine
    let load: Int?

    var body: some View {
        switch addressLine {
        case .authenticationRequired:
            message(Text(Localizable.headerVpnTrafficBlocked))
        case .killSwitchActive:
            message(Text(Localizable.killSwitchAdvancedBannerMessage))
        case let .address(address):
            addressAndLoad(address ?? Localizable.unavailable)
        }
    }

    private func message(_ text: Text) -> some View {
        text
            .themeFont(.headline())
            .foregroundStyle(Color(.text))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(AccessibilityIdentifiers.ipLabel)
    }

    private func addressAndLoad(_ address: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Dimensions.rowSpacing) {
            Text(addressText(address))
                .themeFont(.headline())
                .foregroundStyle(Color(.text))
                .lineLimit(1)
                .accessibilityIdentifier(AccessibilityIdentifiers.ipLabel)

            Spacer(minLength: Dimensions.rowSpacing)

            if let load {
                HeaderLoadView(load: load)
            }
        }
        .frame(height: Dimensions.rowHeight)
    }

    /// The localized "IP: <address>" line, with only the address emphasised.
    private func addressText(_ address: String) -> AttributedString {
        var line = AttributedString(Localizable.ipValue(address))
        if let range = line.range(of: address) {
            line[range].font = .themeFont(.headline(emphasised: true))
        }
        return line
    }

    private enum Dimensions {
        static let rowHeight: CGFloat = 16
        static let rowSpacing: CGFloat = 4
    }
}

/// The server's load as text plus a ring; either full or short + tooltip
struct HeaderLoadView: View {
    let load: Int

    var body: some View {
        HStack(spacing: Dimensions.spacing) {
            ViewThatFits(in: .horizontal) {
                text(Localizable.serverLoadPercentage(load))
                text("\(load)%")
            }
            .help(Localizable.serverLoadPercentage(load))

            LoadCircleView(load: load)
        }
    }

    private func text(_ value: String) -> some View {
        Text(value)
            .themeFont(.callout())
            .foregroundStyle(Color(.text))
            .lineLimit(1)
    }

    private enum Dimensions {
        static let spacing: CGFloat = 4
    }
}

/// The protocol in use on the leading edge, transfer rates on the trailing edge.
struct HeaderProtocolRow: View {
    let vpnProtocolName: String?
    let bitrate: Bitrate?

    var body: some View {
        // While disconnected there is neither a protocol nor a rate, and an empty row would only take
        // space from the message above it.
        if vpnProtocolName != nil || bitrate != nil {
            HStack(alignment: .firstTextBaseline, spacing: Dimensions.rowSpacing) {
                if let vpnProtocolName {
                    text(Text(vpnProtocolName))
                        .accessibilityIdentifier(AccessibilityIdentifiers.protocolLabel)
                }
                Spacer(minLength: Dimensions.rowSpacing)
                if let bitrate {
                    speed(bitrate)
                }
            }
            .frame(height: Dimensions.rowHeight)
        }
    }

    private func speed(_ bitrate: Bitrate) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            arrow(Theme.Asset.Icons.arrowDown.swiftUIImage)
            text(Text(" \(rate(bitrate.download))  "))
            arrow(Theme.Asset.Icons.arrowUp.swiftUIImage)
            text(Text(" \(rate(bitrate.upload))"))
        }
    }

    private func arrow(_ image: Image) -> some View {
        image
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(Color(.icon))
            .frame(.square(Dimensions.arrowSize))
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
    }

    /// Bytes per second in the largest unit that keeps the number small.
    private func rate(_ bytesPerSecond: UInt32) -> String {
        let value = Double(bytesPerSecond)
        switch value {
        case pow(1024, 3)...:
            return "\(String(format: "%.1f", value / pow(1024, 3))) GB/s"
        case pow(1024, 2)...:
            return "\(String(format: "%.1f", value / pow(1024, 2))) MB/s"
        case 1024...:
            return "\(String(format: "%.1f", value / 1024)) KB/s"
        default:
            return "\(String(format: "%.1f", value)) B/s"
        }
    }

    private func text(_ text: Text) -> some View {
        text
            .themeFont(.callout())
            .foregroundStyle(Color(.text))
            .lineLimit(1)
    }

    private enum Dimensions {
        static let rowHeight: CGFloat = 16
        static let rowSpacing: CGFloat = 4
        static let arrowSize: CGFloat = 12
    }
}
