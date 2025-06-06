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

import Perception

import Hermes
import Strings
import Theme
import SwiftUINavigation

struct HermesSettingsView: View {
    enum Sheet {
        case insertion
    }

    @Perception.Bindable var viewModel: HermesSettingsViewModel

    @Environment(\.dismiss) private var dismiss

    @State fileprivate var sheet: Sheet?
    @State private var resolverLocation: String = ""

    private var isEnabledBinding: Binding<Bool> {
        return .init { viewModel.isEnabled } set: { newValue in
            withAnimation { viewModel.setIsEnabled(newValue) }
        }
    }

    private var resolversCount: Int {
        viewModel.activeHermesResolvers.count
    }

    var body: some View {
        ZStack {
            Color(.background, .transparent)
                .ignoresSafeArea()

            contentView
                .animation(.bouncy, value: viewModel.isEnabled)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if resolversCount == 0 || (viewModel.isEnabled && resolversCount > 0) {
                    Button(Localizable.hermesEntitiesFormAddButtonFull) {
                        if viewModel.isEnabled {
                            sheet = .insertion
                        } else {
                            isEnabledBinding.wrappedValue = true
                        }
                    }
                    .padding()
                    .buttonStyle(.hermesAddResolver(fillHorizontalSpace: true))
                    .transition(.opacity)
                }
            }
            .animation(.bouncy, value: viewModel.isEnabled)
        }
        .alert(item: $viewModel.alert) { alert in
            Text(alert.title)
        } actions: { alert in
            if case .hermesOnConflict = alert {
                Button(Localizable.learnMore) {
                    viewModel.openLearnMore()
                }
                Button(Localizable.enable) {
                    viewModel.userEnablingHermesConfirmation()
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
            VStack(spacing: .zero) {
                hermesPresentationView(alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                List {
                    Section {
                        Toggle(isOn: isEnabledBinding) {
                            Text(Localizable.hermesFeatureTitle)
                        }
                        .tint(Color(.background, [.interactive]))
                        .padding(.vertical, .themeSpacing4)
                    }

                    if viewModel.isEnabled && resolversCount > 0 {
                        Section(Localizable.hermesEntitiesHeader(resolversCount)) {
                            hermesResolversContentView(resolversCount: resolversCount)
                        }

                        Text(resolversCount > 1 ? Localizable.hermesEntitiesFootnoteMultiple : Localizable.hermesEntitiesFootnoteSingle)
                            .themeFont(.body2(emphasised: false))
                            .foregroundStyle(Color(.text, .hint))
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: .themeSpacing2, bottom: 0, trailing: .themeSpacing2))
                    }
                }
                .basedOnSizeScrollBehavior()
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        } else {
            hermesPresentationView(alignment: .center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

                Text(Localizable.hermesFeatureDescription)
                    .themeFont(.body3(emphasised: false))
            }
        }
        .padding()
    }
}

private struct HermesResolverListViewCell: View {
    let resolver: HermesResolver
    let isSingleResolver: Bool
    let onDeleteAction: (() -> Void)?

    var body: some View {
        HStack {
            if !isSingleResolver {
                Asset.hermesDragIcon.swiftUIImage
                    .allowsHitTesting(false)
            }

            Text(resolver.location)

            if let onDeleteAction {
                Spacer()

                Button(role: .destructive, action: onDeleteAction) {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(.primary)
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
    @Perception.Bindable var viewModel: HermesSettingsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var resolverLocation: String = ""
    @State private var resolverLocationValidation: HermesSettingsViewModel.LocationValidation = .valid

    @FocusState private var textFieldIsFocused: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                HStack {
                    TextField(text: $resolverLocation) {
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
                    .disabled(resolverLocationValidation == .empty)
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
        case .empty, .valid:
            return RoundedRectangle(cornerRadius: .themeSpacing8).stroke(Color.purple)
        case .invalid, .duplicate, .unexpectedError:
            return RoundedRectangle(cornerRadius: .themeSpacing8).stroke(Color.red)
        }
    }

    @ViewBuilder
    private var locationValidationView: some View {
        switch resolverLocationValidation {
        case .valid, .empty:
            Text(Localizable.hermesEntitiesFormValidationEnterAddress)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
        case .invalid:
            Text(Localizable.hermesEntitiesFormValidationEnterValidAddress)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color.red)
        case .duplicate:
            Text(Localizable.hermesEntitiesFormValidationDuplicate)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color.red)
        case .unexpectedError:
            Text(Localizable.hermesEntitiesFormValidationUnexpectedError)
                .themeFont(.caption(emphasised: false))
                .foregroundStyle(Color.red)
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

private extension List {
    @ViewBuilder
    func basedOnSizeScrollBehavior(axes: Axis.Set = [.vertical]) -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize, axes: axes)
        } else {
            self
        }
    }
}
