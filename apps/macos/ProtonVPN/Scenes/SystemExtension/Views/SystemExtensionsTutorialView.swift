//
//  Created on 02/03/2023.
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

import AppKit
import AVKit
import SwiftUI

import Dependencies

import ProtonCoreUIFoundations

import Domain
import LegacyCommon
import VPNAppCore

import Ergonomics
import Strings

struct SystemExtensionsTutorialView: View {
    struct Model {
        let isSequoiaOrNewer: Bool
        let origin: SystemExtensionTourAlert.Origin
    }

    @Dependency(\.linkOpener) var linkOpener

    let model: Model

    private static let viewSize = CGSize(width: 864, height: 574)
    private static let viewMaxWidth: CGFloat = 542

    static let securityPreferencesUrlString = "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.system_extension.network_extension.extension-point"

    var body: some View {
        VStack(spacing: .themeSpacing32) {
            Group {
                titleView
                howToEnableView
                buttonsView
            }
            .frame(maxWidth: Self.viewMaxWidth)
        }
        .frame(width: Self.viewSize.width, height: Self.viewSize.height)
        .background(Color(.background, .weak))
    }

    private func featureView(_ feature: SystemExtensionTourAlert.Feature) -> some View {
        HStack(spacing: .themeSpacing8) {
            Text(feature.title)
                .themeFont(.body(emphasised: true))
                .foregroundStyle(Color(.text))
            IconProvider.infoCircleFilled
                .resizable()
                .frame(.square(.themeSpacing16))
                .foregroundStyle(Color(.icon, .weak))
        }
        .padding(.themeSpacing8)
        .background(Color(.background, .transparent))
        .linkPointer()
        .clipRectangle(cornerRadius: .radius8)
        .help(feature.hint)
    }

    private var titleView: some View {
        VStack(spacing: .themeSpacing16) {
            VStack(alignment: .center, spacing: .themeSpacing8) {
                Text(model.title)
                    .themeFont(.title1(emphasised: true))
                    .foregroundStyle(Color(.text))
                Text(model.subtitle)
                    .themeFont(.body(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
            }
            .multilineTextAlignment(.center)
            HStack(spacing: .themeSpacing16) {
                ForEach(model.features, id: \.title, content: featureView)
            }
        }
    }

    private var buttonsView: some View {
        VStack(spacing: .themeSpacing16) {
            Button(model.buttonText) {
                linkOpener.open(Self.securityPreferencesUrlString)
            }
            .buttonStyle(ThemeButtonStyle(padding: .medium, style: .primary))

            Button(model.helpText) {
                linkOpener.open(model.helpLink)
            }
            .buttonStyle(LinkButtonStyle())
        }
    }

    private var howToEnableView: some View {
        VStack(alignment: .leading, spacing: .themeSpacing8) {
            Text(Localizable.sysexTutorialHowToEnable)
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
            let steps = Array(zip(1 ... model.steps.count, model.steps))
            ForEach(steps, id: \.0, content: stepView)
        }
        .padding(.top, .themeSpacing24)
        .padding([.bottom, .horizontal], .themeSpacing32)
        .themeBorder(cornerRadius: .radius16)
    }

    private func stepView(number: Int, text: String) -> some View {
        HStack(spacing: .themeSpacing16) {
            Text(String(number))
                .themeFont(.headline(emphasised: true))
                .foregroundStyle(Color(.text))
                .frame(.square(.themeSpacing32))
                .themeBorder(cornerRadius: .radius32)
                .padding(.vertical, .themeSpacing4)
                .padding(.horizontal, .themeSpacing8)
            Text(LocalizedStringKey(text))
                .themeFont(.body(emphasised: false))
                .foregroundStyle(Color(.text))
        }
    }
}

// MARK: - Model extensions

extension SystemExtensionsTutorialView.Model {
    var title: String {
        switch origin {
        case .firstAppLaunch:
            Localizable.sysexTutorialTitleSetup
        case let .inAppPrompt(features):
            if features.isEmpty {
                Localizable.sysexTutorialTitleEnableProton
            } else {
                Localizable.sysexTutorialTitleEnable
            }
        }
    }

    var subtitle: String {
        switch origin {
        case .firstAppLaunch:
            Localizable.sysexTutorialSubtitleApp
        case let .inAppPrompt(features):
            if features.isEmpty {
                Localizable.sysexTutorialSubtitleFeatures
            } else if features.contains(.splitTunneling) {
                Localizable.sysexTutorialSubtitleSt
            } else {
                Localizable.sysexTutorialSubtitleWg
            }
        }
    }

    var features: [SystemExtensionTourAlert.Feature] {
        guard case let .inAppPrompt(features) = origin else {
            return SystemExtensionTourAlert.Feature.allCases
        }
        return features
    }

    var buttonText: String {
        if isSequoiaOrNewer {
            Localizable.sysexTutorialButtonOpen
        } else {
            Localizable.sysexOpenSystemSettings
        }
    }

    var helpText: String {
        if isSequoiaOrNewer {
            Localizable.sysexTutorialDidntWork
        } else {
            Localizable.sysexTutorialNeedHelp
        }
    }

    var helpLink: VPNLink {
        if features.contains(.splitTunneling) {
            .learnMorePlutonium
        } else if isSequoiaOrNewer {
            .systemExtensionsInstallationHelpMacOS15
        } else {
            .systemExtensionsInstallationHelp
        }
    }

    var steps: [String] {
        let turnOnStep = switch origin {
        case .firstAppLaunch:
            Localizable.sysexTutorialStepTurnOnBothOk
        case let .inAppPrompt(features):
            switch (features.contains(.wireguard), features.contains(.splitTunneling)) {
            case (true, true):
                if isSequoiaOrNewer {
                    Localizable.sysexTutorialStepTurnOnBothDone
                } else {
                    Localizable.sysexTutorialStepTurnOnBothOk
                }
            case (true, false):
                if isSequoiaOrNewer {
                    Localizable.sysexTutorialStepTurnOnWgDone
                } else {
                    Localizable.sysexTutorialStepTurnOnWgOk
                }
            case (false, true):
                if isSequoiaOrNewer {
                    Localizable.sysexTutorialStepTurnOnStDone
                } else {
                    Localizable.sysexTutorialStepTurnOnStOk
                }
            case (false, false):
                if isSequoiaOrNewer {
                    Localizable.sysexTutorialStepTurnOnExtensionsDone
                } else {
                    Localizable.sysexTutorialStepTurnOnExtensionsOk
                }
            }
        }

        if isSequoiaOrNewer {
            return [
                Localizable.sysexTutorialStepClickOpen,
                turnOnStep,
                Localizable.sysexTutorialStepAuthenticate,
            ]
        } else {
            return [
                Localizable.sysexTutorialStepClickSecurity,
                Localizable.sysexTutorialStepClickAllow,
                Localizable.sysexTutorialStepAuthenticateDetails,
                turnOnStep,
            ]
        }
    }
}

extension SystemExtensionTourAlert.Feature {
    var title: String {
        switch self {
        case .wireguard:
            Localizable.wireguard
        case .splitTunneling:
            Localizable.plutoniumTitle
        }
    }

    var hint: String {
        switch self {
        case .wireguard:
            Localizable.sysexTutorialFeatureWg
        case .splitTunneling:
            Localizable.sysexTutorialFeatureSt
        }
    }
}
