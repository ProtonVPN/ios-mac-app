//
//  Created on 2025-04-04 by Pawel Jurczyk.
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

import Foundation
import SwiftUI

import ComposableArchitecture
import Dependencies

import ProtonCoreUIFoundations

import Domain
import SettingsShared
import Strings
import Theme
import UniformTypeIdentifiers
import VPNAppCore

public struct PlutoniumView: View {
    @Perception.Bindable public var store: StoreOf<PlutoniumFeature>

    public init(store: StoreOf<PlutoniumFeature>) {
        self.store = store
    }

    static let appsSectionWidth: CGFloat = 308

    @State var appsSheet = false
    @State var ipsSheet = false

    @State private var dragOver = false

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: .themeSpacing24) {
                configView
                if case .enabled = store.feature {
                    listsView
                }
                if store.requiresReconnection {
                    reconnectionNotice()
                }
                Spacer(minLength: 0)
            }
            .frame(width: Constants.readableContentWidth)
            .padding(.vertical, .themeSpacing24)
            .sheet(isPresented: $appsSheet) {
                WithPerceptionTracking {
                    appsList()
                }
            }
            .sheet(isPresented: $ipsSheet) {
                WithPerceptionTracking {
                    ipsList()
                }
            }
            .task {
                store.send(.onAppear)
            }
        }
    }

    private func reconnectionNotice() -> some View {
        HStack(spacing: .themeSpacing8) {
            IconProvider
                .infoCircle
                .resizable()
                .frame(.square(.themeSpacing16))
            Text(Localizable.plutoniumReconnectionNotice)
                .themeFont(.callout(emphasised: false))
            Spacer()
        }
        .foregroundStyle(Color(.text, .hint))
    }

    private func isOnBinding() -> Binding<Bool> {
        .init(
            get: {
                if case .enabled = store.feature { return true }
                return false
            }, set: {
                store.send(.toggleModeClicked($0))
            }
        )
    }

    private var configView: some View {
        HStack(alignment: .top, spacing: .themeSpacing8) {
            modesSelector
            Spacer()
            Toggle(isOn: isOnBinding(), label: { EmptyView() })
                .toggleStyle(ThemeToggleStyle())
        }
        .padding(.vertical, .themeSpacing24)
        .padding(.horizontal, .themeSpacing16)
        .background(Color(.background, .transparent))
        .themeBorder(style: .weak, cornerRadius: .radius12)
    }

    private var listsView: some View {
        VStack(spacing: 0) {
            Button {
                appsSheet.toggle()
            } label: {
                PlutoniumSelectionButtonLabel(mode: store.feature.mode, listType: .apps)
            }

            Divider()

            Button {
                ipsSheet.toggle()
            } label: {
                PlutoniumSelectionButtonLabel(mode: store.feature.mode, listType: .ips)
            }
        }
        .buttonStyle(.plain)
        .background(Color(.background, .transparent))
        .themeBorder(style: .weak, cornerRadius: .radius12)
    }

    private func selectionBinding() -> Binding<PlutoniumFeatureToggle.Mode> {
        .init(
            get: {
                store.feature.mode
            }, set: {
                store.send(.modeSelectionClicked($0))
            }
        )
    }

    private var modesSelector: some View {
        VStack(alignment: .leading, spacing: .themeSpacing2) {
            Text(Localizable.plutoniumTitle)
                .themeFont(.title3(emphasised: true))
                .foregroundStyle(Color(.text))
            VStack(alignment: .leading, spacing: 0) {
                Text(Localizable.plutoniumCustomizeConnection)
                    .themeFont(.body(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
                Link(destination: VPNLink.learnMorePlutonium.url) {
                    Text(Localizable.learnMore)
                        .themeFont(.body(emphasised: true))
                        .foregroundStyle(Color(.text, [.interactive, .hint]))
                }
            }
            if case .enabled = store.feature {
                Spacer().frame(height: .themeSpacing24)
                Picker("", selection: selectionBinding()) {
                    pickerContent()
                }
                .pickerStyle(.inline)
            }
        }
    }

    private var appsHeaderTitle: String {
        guard case let .enabled(mode) = store.feature else { return "" }
        switch mode {
        case .exclusion:
            return Localizable.plutoniumExclusionListApps
        case .inclusion:
            return Localizable.plutoniumInclusionListApps
        }
    }

    private var appsHeaderSubtitle: String {
        guard case let .enabled(mode) = store.feature else { return "" }
        switch mode {
        case .exclusion:
            return Localizable.plutoniumExcludeModeApps
        case .inclusion:
            return Localizable.plutoniumIncludeModeApps
        }
    }

    private var ipsHeaderTitle: String {
        guard case let .enabled(mode) = store.feature else { return "" }
        switch mode {
        case .exclusion:
            return Localizable.plutoniumExcludeModeIps
        case .inclusion:
            return Localizable.plutoniumIncludeModeIps
        }
    }

    private var emptyIpListView: some View {
        VStack(spacing: .themeSpacing8) {
            Spacer()
            Theme.Asset.stars.swiftUIImage
            Text(Localizable.plutoniumEmptyIpListContent)
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
            Spacer()
        }
    }

    private func ipsList() -> some View {
        VStack(spacing: 0) {
            ipEntryView()
            if store.activatedIPs.isEmpty {
                emptyIpListView
            } else {
                activatedIPsList()
                Spacer(minLength: 0)
            }
            doneButton { ipsSheet.toggle() }
        }
        .padding(.horizontal, .themeSpacing16)
        .frame(Constants.settingsAddIPViewSize)
        .background(Color(.background, .weak))
    }

    private func submitIP() {
        guard store.validationError == nil else { return }
        store.send(.entryClicked(.ip(store.ipEntry), .add, store.feature.mode))
    }

    private func ipEntryView() -> some View {
        VStack(alignment: .leading, spacing: .themeSpacing12) {
            Text(ipsHeaderTitle)
                .themeFont(.body(emphasised: true))
                .foregroundStyle(Color(.text))
            HStack {
                TextField("", text: $store.ipEntry.sending(\.inputFieldChanged))
                    .clearButton(text: $store.ipEntry.sending(\.inputFieldChanged))
                    .disableAutocorrection(true)
                    .onSubmit(submitIP)
                    .textFieldStyle(.plain)
                    .font(.callout(emphasised: false))
                    .foregroundStyle(Color(.text))
                    .padding(.themeSpacing8)
                    .background(Color(.background, .transparent))
                    .themeBorder(style: store.validationError != nil ? .danger : .normal, cornerRadius: .radius8)

                Button(action: submitIP) {
                    Text(Localizable.plutoniumAddButton)
                }
                .disabled(store.validationError != nil || store.ipEntry.isEmpty)
                .buttonStyle(ThemeButtonStyle(padding: .small, style: .secondary))
            }

            if let error = store.validationError?.errorDescription {
                Text(error)
                    .themeFont(.body(emphasised: false))
                    .foregroundStyle(Color(.text, .danger))
            }
        }
        .padding(.vertical, .themeSpacing24)
    }

    private func activatedIPsList() -> some View {
        ScrollView {
            LazyVStack {
                ForEach(store.activatedIPs, id: \.self, content: ipView(ip:))
            }
        }
    }

    private func ipView(ip: String) -> some View {
        HStack {
            Text(ip)
                .themeFont(.body(emphasised: false))
                .foregroundStyle(Color(.text))
            Spacer()
            Button {
                store.send(.entryClicked(.ip(ip), .remove, store.feature.mode))
            } label: {
                IconProvider.cross
                    .resizable()
                    .frame(.square(.themeSpacing16))
                    .padding(.themeSpacing4)
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    private func appsList() -> some View {
        VStack {
            HStack(spacing: .themeRadius8) {
                appsSection(title: Localizable.plutoniumAllApps,
                            subtitle: nil,
                            apps: store.remainingApps,
                            operation: .add)
                appsSection(title: appsHeaderTitle,
                            subtitle: appsHeaderSubtitle,
                            apps: store.activatedApps,
                            operation: .remove)
            }
            doneButton { appsSheet.toggle() }
        }
        .padding([.horizontal, .top], .themeSpacing16)
        .background(Color(.background, .weak))
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dragOver, perform: performDrop)
    }

    private func performDrop(providers: [NSItemProvider]) -> Bool {
        providers
            .map(ItemProvider.init(provider:))
            .forEach { provider in
                Task { @MainActor in
                    guard let url = await provider.loadFileURL(),
                          let app = PlutoniumApp(url: url) else {
                        log.debug("Tried to add an invalid app URL")
                        return
                    }
                    store.send(.entryClicked(.app(app), .add, store.feature.mode))
                }
            }
        return true
    }

    private func doneButton(action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button {
                action()
            } label: {
                Text(Localizable.done)
            }
            .buttonStyle(ThemeButtonStyle(padding: .small))
            .padding(.vertical, .themeSpacing16)
        }
    }

    private func appsHeader(title: String, subtitle: String?) -> some View {
        VStack(spacing: .themeSpacing2) {
            HStack {
                Text(title)
                    .themeFont(.body(emphasised: true))
                    .foregroundStyle(Color(.text))
                Spacer()
            }
            if let subtitle {
                HStack {
                    Text(subtitle)
                        .themeFont(.callout(emphasised: false))
                        .foregroundStyle(Color(.text, .weak))
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.themeSpacing12)
    }

    private func appsSection(title: String, subtitle: String?, apps: [PlutoniumApp], operation: PlutoniumFeature.State.Operation) -> some View {
        VStack(spacing: 0) {
            appsHeader(title: title, subtitle: subtitle)
            if apps.isEmpty, operation == .remove {
                VStack(spacing: .themeSpacing8) {
                    Spacer()
                    Theme.Asset.plutonium.swiftUIImage
                    Text(Localizable.plutoniumNoApps)
                        .themeFont(.callout(emphasised: false))
                        .foregroundStyle(Color(.text, .weak))
                    Spacer()
                }
            } else {
                appsRows(apps: apps, operation: operation)
                Spacer(minLength: 0)
            }
        }
        .frame(width: Self.appsSectionWidth)
        .background(Color(.background, (operation == .remove && dragOver) ? [.transparent, .hovered] : [.transparent]))
        .clipRectangle(cornerRadius: .radius8)
        .themeBorder(style: [],
                     dashed: operation == .remove && dragOver,
                     lineWidth: (operation == .remove && dragOver) ? 2 : 0,
                     cornerRadius: .radius8)
    }

    private func openPanelLabel() -> some View {
        VStack(alignment: .leading, spacing: .themeSpacing2) {
            HStack {
                Text(Localizable.plutoniumImportAppsTitle)
                    .themeFont(.callout(emphasised: false))
                    .foregroundStyle(Color(.text))
                Spacer()
            }
            Text(Localizable.plutoniumImportAppsSubtitle1)
                .themeFont(.footnote(emphasised: false))
                .foregroundColor(Color(.text, .hint))
                + Text(Localizable.plutoniumImportAppsSubtitle2)
                .themeFont(.footnote(emphasised: false))
                .foregroundColor(Color(.text, [.interactive, .hint]))
        }
        .padding(.themeSpacing8)
    }

    private func openPanelAction() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        panel.urls
            .compactMap(PlutoniumApp.init(url:))
            .forEach {
                store.send(.entryClicked(.app($0), .add, store.feature.mode))
            }
    }

    private func appsRows(apps: [PlutoniumApp], operation: PlutoniumFeature.State.Operation) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(apps) { app in
                    Button {
                        store.send(.entryClicked(.app(app), operation, store.feature.mode))
                    } label: {
                        appRow(app, operation: operation)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                if operation == .add {
                    Button(action: openPanelAction, label: openPanelLabel)
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(.horizontal, .themeSpacing4)
            .padding(.bottom, .themeSpacing4)
        }
    }

    private func appRow(_ app: PlutoniumApp, operation: PlutoniumFeature.State.Operation) -> some View {
        HStack(spacing: .themeSpacing8) {
            operation
                .icon
                .resizable()
                .frame(.square(.themeSpacing16))
            app
                .icon
                .resizable()
                .frame(.square(.themeSpacing24))

            Text(app.title)
            Spacer(minLength: 0)
        }
        .padding(.vertical, .themeSpacing4)
        .padding(.horizontal, .themeSpacing8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func pickerContent() -> some View {
        ForEach(PlutoniumFeatureToggle.Mode.allCases, id: \.self) {
            switch $0 {
            case .exclusion:
                VStack(alignment: .leading) {
                    Text(Localizable.plutoniumExcludeMode)
                        .themeFont(.body(emphasised: true))
                        .foregroundStyle(Color(.text))
                    Text(Localizable.plutoniumExcludeModeDescription)
                        .themeFont(.body(emphasised: false))
                        .foregroundStyle(Color(.text, .weak))
                    Spacer().frame(height: .themeSpacing8)
                }
            case .inclusion:
                VStack(alignment: .leading) {
                    Text(Localizable.plutoniumIncludeMode)
                        .themeFont(.body(emphasised: true))
                        .foregroundStyle(Color(.text))
                    Text(Localizable.plutoniumIncludeModeDescription)
                        .themeFont(.body(emphasised: false))
                        .foregroundStyle(Color(.text, .weak))
                }
            }
        }
    }
}

extension PlutoniumFeature.State.Operation {
    var icon: Image {
        switch self {
        case .add:
            IconProvider.plusCircle
        case .remove:
            IconProvider.minusCircle
        }
    }
}

extension PlutoniumFeature.State.ValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            Localizable.plutoniumAddressExists
        case .invalidIP:
            Localizable.plutoniumValidationError
        }
    }
}
