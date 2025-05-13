//
//  Created on 04/04/2025 by adam.
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

import Dependencies
import Domain
import Hermes
import LegacyCommon
import ProtonCoreUIFoundations
import Sharing
import Strings
import Theme

struct HermesView: ExplicitlySizedView {
    static let viewSize: CGSize = .init(width: 752, height: 600)

    let viewModel: HermesViewModel

    @State private var resolverLocation: String = ""
    @State private var resolverLocationValidation: HermesViewModel.LocationValidation = .valid

    @FocusState private var locationTextFieldIsFocused: Bool

    private var isEnabledBinding: Binding<Bool> {
        return .init { viewModel.isEnabled } set: { newValue in
            viewModel.setIsEnabled(newValue)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HermesSectionView {
                HStack {
                    VStack(alignment: .leading, spacing: .zero) {
                        Text(Localizable.hermesFeatureTitle)
                            .themeFont(.title3(emphasised: true))
                            .foregroundStyle(Color.white)
                        Text(Localizable.hermesFeatureDescription)
                            .themeFont(.body(emphasised: false))
                            .foregroundStyle(Color(.text, .weak))
                    }

                    Spacer()

                    Toggle(isOn: isEnabledBinding) { EmptyView() }
                        .onSubmit { isEnabledBinding.wrappedValue = !isEnabledBinding.wrappedValue }
                        .toggleStyle(ThemeToggleStyle())
                }
            }

            if isEnabledBinding.wrappedValue {
                resolversContent
            }
        }
        .onAppear {
            locationTextFieldIsFocused = isEnabledBinding.wrappedValue
        }
        .onTapGesture {
            locationTextFieldIsFocused = false
        }
        .onChange(of: isEnabledBinding.wrappedValue, to: true) { _ in
            resolverLocation = ""
            resolverLocationValidation = .valid
        }
        .animation(.bouncy, value: isEnabledBinding.wrappedValue)
        .padding(.vertical, .themeSpacing24)
        .padding(.horizontal, 40.0)
        .frame(width: Self.viewSize.width, height: Self.viewSize.height, alignment: .top)
        .background(Color(.background, .normal))
    }

    @ViewBuilder
    private var resolversContent: some View {
        let resolvers = viewModel.activeHermesResolvers

        Text(Localizable.hermesEntitiesHeader(resolvers.count))
            .themeFont(.callout(emphasised: false))
            .foregroundStyle(Color(.text, .weak))
            .padding(.top, .themeSpacing24)

        VStack(alignment: .leading, spacing: .themeSpacing16) {
            Text(Localizable.hermesEntitiesFormHeader)
                .themeFont(.title3(emphasised: true))
                .foregroundStyle(Color(.text, .normal))

            locationInputView

            locationValidationView

            Text(Localizable.hermesEntitiesFootnote)
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color(.text, .hint))

            resolversListView
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing24)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: .themeSpacing12, style: .continuous))
        .onChange(of: resolverLocation) { newValue in
            resolverLocationValidation = viewModel.validate(location: newValue)
        }
    }

    private var locationInputView: some View {
        HStack {
            TextField(Localizable.hermesEntitiesFormPlaceholder, text: $resolverLocation)
                .onSubmit { submitResolverLocation() }
                .focused($locationTextFieldIsFocused)
                .controlSize(.large)
                .overlay(locationTextFieldIsFocused ? resolverLocationOverlay : nil)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            Button(Localizable.hermesEntitiesFormAddButton) {
                submitResolverLocation()
            }
            .disabled(resolverLocationValidation == .empty)
            .buttonStyle(ThemeButtonStyle(padding: .small, style: .primary))
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

    private func submitResolverLocation() {
        if viewModel.addResolver(with: resolverLocation) {
            resolverLocation = ""
        } else {
            resolverLocationValidation = .unexpectedError
        }
    }

    @ViewBuilder
    private var locationValidationView: some View {
        switch resolverLocationValidation {
        case .valid, .empty:
            Text(Localizable.hermesEntitiesFormValidationEnterAddress)
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
        case .invalid:
            Text(Localizable.hermesEntitiesFormValidationEnterValidAddress)
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color.red)
        case .duplicate:
            Text(Localizable.hermesEntitiesFormValidationDuplicate)
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color.red)
        case .unexpectedError:
            Text(Localizable.hermesEntitiesFormValidationUnexpectedError)
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color.red)
        }
    }

    private var resolversListView: some View {
        List {
            let resolvers = viewModel.activeHermesResolvers
            let singleResolver = resolvers.count == 1

            ForEach(resolvers, id: \.self) { resolver in
                cell(forResolver: resolver, isSingleResolver: singleResolver)
                    .frame(height: 40.0)
                    .listRowSeparator(.hidden)
                    .help(Localizable.hermesEntitiesCopyAction)
                    .onTapGesture(count: 2) {
                        setPasteboard(to: resolver.location)
                    }
            }
            .onMove { src, dst in
                viewModel.moveResolvers(from: src, to: dst)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    @discardableResult
    private func setPasteboard(to newContent: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(newContent, forType: .string)
    }

    private func cell(forResolver resolver: HermesResolver, isSingleResolver: Bool) -> some View {
        HStack {
            if !isSingleResolver {
                Asset.hermesDragIcon.swiftUIImage
                    .disabled(true)
            }

            Text(resolver.location)
                .themeFont(.body(emphasised: false))

            Spacer()

            Button(role: .destructive) {
                _ = viewModel.removeResolver(resolver)
            } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundStyle(.primary)
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HermesSectionView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .themeSpacing24)
            .padding(.vertical, .themeSpacing24)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: .themeSpacing12, style: .continuous))
    }
}

final class HermesWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    init(viewModel: HermesViewModel) {
        let mask: NSWindow.StyleMask = [.closable, .titled, .fullSizeContentView]

        super.init(contentRect: .zero, styleMask: mask, backing: .buffered, defer: false)

        let hermesView = HermesView(viewModel: viewModel)
        let hostingViewController = ExplicitlySizedHostingController(rootView: hermesView)
        contentViewController = hostingViewController

        title = Localizable.hermesFeatureWindowTitle
        titlebarAppearsTransparent = true
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .color(.background, .weak)
    }
}
