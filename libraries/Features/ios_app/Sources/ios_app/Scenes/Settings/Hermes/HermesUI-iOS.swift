//
//  Created on 23/05/2025 by adam.
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
import UIKit

import SwiftUINavigation

import Domain
import Hermes
import Strings
import Theme

struct HermesSettingsView: View {
    enum Sheet {
        case insertion
    }

    @Bindable var viewModel: HermesSettingsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var canScroll: Bool = false
    @State private var sheet: Sheet?
    @State private var resolverLocation: String = ""

    private var isEnabledBinding: Binding<Bool> {
        .init { viewModel.isEnabled } set: { newValue in
            withAnimation { viewModel.setIsEnabled(newValue) }
        }
    }

    private var resolversCount: Int {
        viewModel.activeHermesResolvers.count
    }

    var body: some View {
        ZStack {
            Color(.background, .strong)
                .ignoresSafeArea()

            contentView
                .animation(.bouncy, value: viewModel.isEnabled)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .safeAreaInset(edge: .bottom) {
            ZStack {
                if resolversCount == 0 || (viewModel.isEnabled && resolversCount > 0) {
                    Button(Localizable.hermesEntitiesFormAddButtonFull) {
                        if !viewModel.isEnabled {
                            isEnabledBinding.wrappedValue = true
                        }
                        if viewModel.isEnabled {
                            sheet = .insertion
                        }
                    }
                    .padding([.leading, .trailing, .bottom])
                    .buttonStyle(.hermesAddResolver(fillHorizontalSpace: true))
                    .transition(.opacity)
                }
            }
            .background(Color(.background, .strong))
            .animation(.bouncy, value: viewModel.isEnabled)
        }
        .navigationTitle(canScroll ? Localizable.hermesFeatureTitle : "")
        .alert(item: $viewModel.alert) { alert in
            Text(alert.title)
        } actions: { alert in
            if case .hermesOnConflict = alert {
                Button(Localizable.learnMore) {
                    viewModel.openLearnMore()
                }
                Button(Localizable.enable) {
                    viewModel.userEnablingHermesConfirmation()
                    if resolversCount == 0 {
                        sheet = .insertion
                    }
                }
                Button(Localizable.cancel, role: .cancel) {}
            } else {
                Button(Localizable.ok) {}
            }
        } message: { alert in
            Text(alert.message)
        }
        .sheet(item: $sheet, id: \.self) { _ in
            HermesSettingsInputView(viewModel: viewModel)
        }
    }
}

private extension HermesSettingsView {
    @ViewBuilder
    var contentView: some View {
        if viewModel.isEnabled || resolversCount > 0 {
            List {
                listContentView
            }
            .basedOnSizeScrollBehavior()
            .onScrollGeometryChange(canScroll: $canScroll)
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        } else {
            hermesPresentationView(alignment: .center)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var listContentView: some View {
        hermesPresentationView(alignment: .leading)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity, alignment: .leading)

        Section {
            Toggle(isOn: isEnabledBinding) {
                Text(Localizable.hermesFeatureTitle)
            }
            .tint(Color(.background, [.interactive]))
            .padding(.vertical, .themeSpacing4)
        }
        .listRowBackground(Color(.background))

        if viewModel.isEnabled, resolversCount > 0 {
            Section {
                hermesResolversContentView(resolversCount: resolversCount)
            } header: {
                Text(Localizable.hermesEntitiesHeader(resolversCount))
                    .themeFont(.body2(emphasised: true))
                    .foregroundStyle(Color(.text))
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: .themeSpacing8, trailing: 0))
            }
            .listRowBackground(Color(.background))
            .textCase(nil)

            Text(resolversCount > 1 ? Localizable.hermesEntitiesFootnoteMultiple : Localizable.hermesEntitiesFootnoteSingle)
                .themeFont(.body2(emphasised: false))
                .foregroundStyle(Color(.text, .hint))
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: .themeSpacing2, bottom: 0, trailing: .themeSpacing2))
        }
    }

    @ViewBuilder
    func hermesResolversContentView(resolversCount: Int) -> some View {
        if resolversCount > 1 {
            activeHermesResolversView(resolversCount: resolversCount)
                .onMove { source, dst in
                    viewModel.moveResolvers(source: source, destination: dst)
                }
        } else {
            activeHermesResolversView(resolversCount: resolversCount)
        }
    }

    func activeHermesResolversView(resolversCount: Int) -> ForEach<[HermesResolver], String, HermesResolverListViewCell> {
        ForEach(viewModel.activeHermesResolvers) { resolver in
            HermesResolverListViewCell(resolver: resolver, isSingleResolver: resolversCount == 1) {
                withAnimation { _ = viewModel.removeResolver(resolver) }
            }
        }
    }

    func hermesPresentationView(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: .themeSpacing24) {
            Asset.hermes.swiftUIImage

            VStack(alignment: alignment, spacing: .themeSpacing8) {
                Text(Localizable.hermesFeatureTitle)
                    .themeFont(.headline)
                    .foregroundStyle(Color(.text))

                Text(
                    base: Localizable.hermesFeatureDescription,
                    linkText: Localizable.learnMore,
                    urlString: VPNLink.hermes.urlString
                )
                .foregroundStyle(Color(.text, .weak))
                .multilineTextAlignment(alignment == .center ? .center : .leading)
            }
        }
        .padding(.bottom, .themeSpacing2) // workaround for a cornerRadius clipping effect due to SwiftUI.List
    }
}

private struct HermesResolverListViewCell: View {
    let resolver: HermesResolver
    let isSingleResolver: Bool
    let onDeleteAction: (() -> Void)?

    var body: some View {
        HStack {
            if !isSingleResolver {
                Theme.Asset.hermesDragIcon.swiftUIImage
                    .allowsHitTesting(false)
            }

            Text(resolver.location)

            if let onDeleteAction {
                Spacer()

                Button(role: .destructive, action: onDeleteAction) {
                    Label(Localizable.delete, systemImage: "trash")
                        .foregroundStyle(Color(.icon))
                        .labelStyle(.iconOnly)
                        .padding(.all, .themeSpacing6)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, .themeSpacing2)
        .frame(maxWidth: .infinity)
    }
}

private struct HermesSettingsInputView: View {
    @Bindable var viewModel: HermesSettingsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var resolverLocation: String = ""
    @State private var resolverLocationValidation: HermesSettingsViewModel.LocationValidation = .valid

    @FocusState private var textFieldIsFocused: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                HStack {
                    TextField(text: $resolverLocation, prompt: Text(Localizable.hermesEntitiesFormPlaceholder)) {
                        EmptyView()
                    }
                    .controlSize(.large)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($textFieldIsFocused)
                    .textFieldStyle(.hermesTextFieldStyle(validationState: resolverLocationValidation))
                    .overlay(textFieldIsFocused ? resolverLocationOverlay : nil)
                    .onSubmit {
                        submitResolverLocation()
                    }

                    Button(Localizable.hermesEntitiesFormAddButton) {
                        submitResolverLocation()
                    }
                    .buttonStyle(.hermesAddResolver(addMinPadding: true))
                }

                locationValidationView
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(Localizable.hermesEntitiesFormHeader)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                textFieldIsFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localizable.cancel, role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var resolverLocationOverlay: some View {
        switch resolverLocationValidation {
        case .valid:
            RoundedRectangle(cornerRadius: .themeSpacing8).stroke(Color(.border, .interactive))
        case .empty, .invalid, .duplicate, .unexpectedError:
            RoundedRectangle(cornerRadius: .themeSpacing8).stroke(Color(.border, .danger))
        }
    }

    @ViewBuilder
    private var locationValidationView: some View {
        switch resolverLocationValidation {
        case .valid:
            Text(Localizable.hermesEntitiesFormDescription)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
        case .empty:
            Text(Localizable.hermesEntitiesFormValidationEnterAddress)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color(.text, .danger))
        case .invalid:
            Text(Localizable.hermesEntitiesFormValidationEnterValidAddress)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color(.text, .danger))
        case .duplicate:
            Text(Localizable.hermesEntitiesFormValidationDuplicate)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color(.text, .danger))
        case .unexpectedError:
            Text(Localizable.hermesEntitiesFormValidationUnexpectedError)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color(.text, .danger))
        }
    }

    private func submitResolverLocation() {
        resolverLocationValidation = viewModel.validate(location: resolverLocation)

        guard case .valid = resolverLocationValidation else {
            return
        }

        if viewModel.addResolver(with: resolverLocation) {
            dismiss()
        } else {
            resolverLocationValidation = .unexpectedError
        }
    }
}

// MARK: - SwiftUI Helpers

private extension View {
    @ViewBuilder
    func basedOnSizeScrollBehavior(axes: Axis.Set = [.vertical]) -> some View {
        scrollBounceBehavior(.basedOnSize, axes: axes)
    }

    @ViewBuilder
    func onScrollGeometryChange(canScroll: Binding<Bool>) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: Double.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newValue in
                canScroll.wrappedValue = newValue > 0
            }
        } else {
            self
        }
    }
}

private extension Text {
    init(base: some StringProtocol, linkText: some StringProtocol, urlString: String) {
        var attributedString = AttributedString(base)
        attributedString.font = .themeFont(.body3(emphasised: false))

        if let linkRange = attributedString.range(of: linkText) {
            attributedString[linkRange].link = URL(string: urlString)!
            attributedString[linkRange].font = Font.themeFont(.body3(emphasised: true))
            attributedString[linkRange].foregroundColor = Color(.text, .interactive)
        }

        self.init(attributedString)
    }
}
