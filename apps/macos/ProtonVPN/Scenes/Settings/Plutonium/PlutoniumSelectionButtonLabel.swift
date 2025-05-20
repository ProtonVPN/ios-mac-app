//
//  Created on 2025-05-07 by Pawel Jurczyk.
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

import SwiftUI
import ComposableArchitecture

import ProtonCoreUIFoundations
import Strings

import VPNAppCore

struct PlutoniumSelectionButtonLabel: View {
    enum ListType {
        case apps
        case ips
    }

    let listType: ListType
    let mode: PlutoniumFeatureToggle.Mode

    @State var appsRendered: Set<String> = []
    @State var ipsRendered: Set<String> = []

    @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated
    @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated

    var apps: [PlutoniumApp] {
        switch mode {
        case .exclusion:
            return exclusionActivated.apps
        case .inclusion:
            return inclusionActivated.apps
        }
    }

    var ips: [String] {
        switch mode {
        case .exclusion:
            return exclusionActivated.ips
        case .inclusion:
            return inclusionActivated.ips
        }
    }

    var itemsCount: Int {
        switch listType {
        case .apps:
            return apps.count
        case .ips:
            return ips.count
        }
    }

    var others: Int {
        switch listType {
        case .apps:
            return itemsCount - appsRendered.count
        case .ips:
            return itemsCount - ipsRendered.count
        }
    }

    var title: String {
        switch listType {
        case .apps:
            switch mode {
            case .exclusion:
                return Localizable.plutoniumExclusionListApps
            case .inclusion:
                return Localizable.plutoniumInclusionListApps
            }
        case .ips:
            switch mode {
            case .exclusion:
                return Localizable.plutoniumExcludeModeIps
            case .inclusion:
                return Localizable.plutoniumIncludeModeIps
            }
        }
    }

    public init(mode: PlutoniumFeatureToggle.Mode, listType: ListType) {
        self.mode = mode
        self.listType = listType
    }

    @ViewBuilder
    var activatedListPeek: some View {
        LazyHStack(spacing: .themeSpacing8) {
            switch listType {
            case .apps:
                switch mode {
                case .exclusion:
                    ForEach(exclusionActivated.apps) { item in
                        smallAppView(item: item)
                    }
                case .inclusion:
                    ForEach(inclusionActivated.apps) { item in
                        smallAppView(item: item)
                    }
                }
            case .ips:
                switch mode {
                case .exclusion:
                    ForEach(exclusionActivated.ips, id: \.self) { item in
                        smallIPView(item: item)
                    }
                case .inclusion:
                    ForEach(inclusionActivated.ips, id: \.self) { item in
                        smallIPView(item: item)
                    }
                }
            }
        }
    }

    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: .themeSpacing16) {
                VStack(alignment: .leading, spacing: itemsCount == 0 ? .themeSpacing2 : .themeSpacing8) {
                    Text(title)
                        .themeFont(.body(emphasised: true))
                        .foregroundStyle(Color(.text))
                    HStack(spacing: .themeSpacing8) {
                        ScrollView(.horizontal) {
                            activatedListPeek
                            if itemsCount == 0 {
                                Text(Localizable.plutoniumNone)
                                    .themeFont(.callout(emphasised: false))
                                    .foregroundStyle(Color(.text, .weak))
                            }
                        }
                        .scrollDisabled(true)
                        .layoutPriority(0.9)
                        if others > 0 {
                            Spacer(minLength: 0)
                            Text(Localizable.plutoniumOthers(others))
                                .themeFont(.callout(emphasised: false))
                                .foregroundStyle(Color(.text, .weak))
                                .layoutPriority(1)
                        }
                    }
                    .frame(height: 20)
                }
                Spacer(minLength: 0)
                IconProvider.chevronRight
                    .resizable()
                    .frame(.square(.themeSpacing16))
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.vertical, .themeSpacing12)
            .contentShape(Rectangle())
        }
    }

    private func smallIPView(item: String) -> some View {
        Text(item)
            .themeFont(.callout(emphasised: false))
            .foregroundStyle(Color(.text, .weak))
            .padding(.vertical, .themeSpacing2)
            .padding(.horizontal, .themeSpacing4)
            .background(Color(.background, .transparent))
            .clipRectangle(cornerRadius: .radius4)
            .task {
                ipsRendered.update(with: item)
                ipsRendered = ipsRendered.intersection(ips)
            }
    }

    private func smallAppView(item: PlutoniumApp) -> some View {
        HStack(spacing: .themeSpacing4) {
            item
                .icon
                .resizable()
                .frame(.square(20))
            Text(item.title)
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
        }
        .task {
            appsRendered.update(with: item.bundleIdentifier)
            appsRendered = appsRendered.intersection(apps.map(\.bundleIdentifier))
        }
    }
}
