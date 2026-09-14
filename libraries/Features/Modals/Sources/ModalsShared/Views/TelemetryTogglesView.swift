//
//  Created on 03/02/2023.
//
//  Copyright (c) 2023 Proton AG
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

import Domain
import Sharing
import Strings
import SwiftUI
import Theme
import VPNAppCore

public struct TelemetryTogglesView: View {
    @Binding private var sharesUsageData: Bool
    @Binding private var sharesCrashReports: Bool

    public init(sharesUsageData: Binding<Bool>, sharesCrashReports: Binding<Bool>) {
        _sharesUsageData = sharesUsageData
        _sharesCrashReports = sharesCrashReports
    }

    public var body: some View {
        VStack(spacing: .themeSpacing0) {
            VStack(spacing: .themeSpacing0) {
                TelemetryToggleRow(
                    title: Localizable.onboardingUsageStatsTitle,
                    description: Localizable.onboardingUsageStatsDescription,
                    isOn: $sharesUsageData
                )
                Divider()
                    .background(Color(.border))
                    .padding(.leading, TelemetryTogglesView.contentInset)
                TelemetryToggleRow(
                    title: Localizable.onboardingCrashReportsTitle,
                    description: Localizable.onboardingCrashReportsDescription,
                    isOn: $sharesCrashReports
                )
            }

            TelemetryFooter()
        }
        .frame(maxWidth: Theme.Constants.readableContentWidth)
    }

    public static var contentInset: CGFloat {
        #if os(macOS)
            .themeSpacing24
        #else
            .themeSpacing16
        #endif
    }
}

public struct TelemetrySettingsView: View {
    @Shared(.telemetryUsageData) private var sharesUsageData
    @Shared(.telemetryCrashReports) private var sharesCrashReports

    public init() {}

    public var body: some View {
        TelemetryTogglesView(
            sharesUsageData: Binding {
                sharesUsageData
            } set: { newValue in
                record(usageData: newValue, crashReports: sharesCrashReports)
            },
            sharesCrashReports: Binding {
                sharesCrashReports
            } set: { newValue in
                record(usageData: sharesUsageData, crashReports: newValue)
            }
        )
    }

    private func record(usageData: Bool, crashReports: Bool) {
        TelemetryOptIn.record(sharesUsageData: usageData, sharesCrashReports: crashReports)
    }
}

private struct TelemetryToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: .themeSpacing0) {
                Text(title)
                #if os(macOS)
                    .themeFont(.headline(emphasised: true))
                #else
                    .themeFont(.body1())
                #endif
                    .foregroundStyle(Color(.text))
                    .padding(.bottom, .themeSpacing4)

                Text(description)
                #if os(macOS)
                    .themeFont(.subHeadline())
                #else
                    .themeFont(.caption())
                #endif
                    // Without this the description is truncated on smaller devices.
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Color(.text, .weak))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .tint(Color(.icon, .interactive))
        .padding(.horizontal, TelemetryTogglesView.contentInset)
        .padding(.vertical, .themeSpacing16)
    }
}

private struct TelemetryFooter: View {
    /// Find a way to combine the learn more text and the footer text into one localized string. We
    /// only have one localization that reads right-to-left at the moment, but there will probably be
    /// more in the future.
    private var footnote: Text {
        Text(Localizable.onboardingFooter + " ")
            + Text(Localizable.onboardingFooterLearnMore)
            .foregroundColor(Color(.text, .interactive))
    }

    var body: some View {
        Link(destination: VPNLink.learnMoreTelemetry.url) {
            footnote
            #if os(macOS)
                .themeFont(.subHeadline())
            #else
                .themeFont(.caption())
            #endif
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                // Centered, so it is not part of the left-aligned rhythm the questions set. A
                // narrower column keeps it apart from them and stops "Learn more" breaking lines.
                .padding(.horizontal, TelemetryTogglesView.contentInset + .themeSpacing16)
                .padding(.vertical, .themeSpacing16)
                .foregroundStyle(Color(.text, .weak))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Sharing everything", traits: .sizeThatFitsLayout) {
    TelemetrySettingsView()
}
