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
import Ergonomics
import Hermes
import LegacyCommon
import ProtonCoreUIFoundations
import Sharing
import Strings
import Theme

// MARK: - View Definitions

struct HermesView: ExplicitlySizedView {
    static let viewSize: CGSize = .init(width: 752, height: 600)

    private static let macOSListInterItemVerticalPadding: CGFloat = 4.0
    private static let resolverCellVerticalHeight: CGFloat = 40.0
    private static let resolversListVerticalHeight: CGFloat = 192.0

    let viewModel: HermesViewModel

    @State private var resolverLocation: String = ""
    @State private var resolverLocationValidation: HermesViewModel.LocationValidation = .valid

    @FocusState private var locationTextFieldIsFocused: Bool

    private var isEnabledBinding: Binding<Bool> {
        .init { viewModel.isEnabled } set: { newValue in
            viewModel.setIsEnabled(newValue)
        }
    }

    private var localHermesResolvers: Binding<[HermesResolver]> {
        .init { viewModel.activeHermesResolvers } set: { newValue in
            viewModel.applyDiff(newValue.difference(from: viewModel.activeHermesResolvers))
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HermesSectionView {
                HStack {
                    VStack(alignment: .leading, spacing: .themeSpacing2) {
                        Text(Localizable.hermesFeatureTitle)
                            .themeFont(.title3(emphasised: true))
                            .foregroundStyle(Color.white)
                        Text(Localizable.hermesFeatureDescription)
                            .themeFont(.body(emphasised: false))
                            .foregroundStyle(Color(.text, .weak))
                    }

                    Spacer()

                    Toggle(isOn: isEnabledBinding) { EmptyView() }
                        .onSubmit {
                            withAnimation {
                                isEnabledBinding.wrappedValue = !isEnabledBinding.wrappedValue
                            }
                        }
                        .toggleStyle(ThemeToggleStyle())
                }
                .padding(.horizontal, .themeSpacing16)
                .padding(.vertical, .themeSpacing24)
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
        let resolversCount = localHermesResolvers.count

        Text(Localizable.hermesEntitiesHeader(resolversCount))
            .themeFont(.callout(emphasised: false))
            .foregroundStyle(Color(.text, .weak))
            .padding(.top, .themeSpacing24)

        HermesSectionView {
            VStack(alignment: .leading, spacing: .themeSpacing16) {
                Text(Localizable.hermesEntitiesFormHeader)
                    .themeFont(.title3(emphasised: true))
                    .foregroundStyle(Color(.text, .normal))

                locationInputView

                locationValidationView

                resolversListView

                Text(resolversCount > 1 ? Localizable.hermesEntitiesFootnoteMultiple : Localizable.hermesEntitiesFootnoteSingle)
                    .themeFont(.callout(emphasised: false))
                    .foregroundStyle(Color(.text, .hint))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .themeSpacing16)
            .padding(.vertical, .themeSpacing24)
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
            RoundedRectangle(cornerRadius: .themeSpacing8).stroke(Color.purple)
        case .invalid, .duplicate, .unexpectedError:
            RoundedRectangle(cornerRadius: .themeSpacing8).stroke(Color.red)
        }
    }

    private func submitResolverLocation() {
        resolverLocationValidation = viewModel.validate(location: resolverLocation)

        guard case .valid = resolverLocationValidation else {
            return
        }

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
        let resolversCount = localHermesResolvers.count
        let listHeight = min(
            max(0, CGFloat(localHermesResolvers.count) * (Self.resolverCellVerticalHeight + 2 * Self.macOSListInterItemVerticalPadding)),
            Self.resolversListVerticalHeight
        )
        let editActions: EditActions<[HermesResolver]> = resolversCount > 1 ? [.move] : []
        return List(localHermesResolvers, editActions: editActions) { binding in
            let resolver = binding.wrappedValue
            HermesResolverTableViewCell(resolver: resolver, isSingleResolver: resolversCount == 1) {
                _ = viewModel.removeResolver(resolver)
            }
            .frame(height: Self.resolverCellVerticalHeight)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .help(Localizable.hermesEntitiesCopyAction)
            .onTapGesture(count: 2) {
                setPasteboard(to: resolver.location)
            }
        }
        .frame(height: listHeight)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @discardableResult
    private func setPasteboard(to newContent: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(newContent, forType: .string)
    }
}

private struct HermesResolverTableViewCell: View {
    let resolver: HermesResolver
    let isSingleResolver: Bool
    let onDeleteAction: () -> Void

    var body: some View {
        HStack {
            if !isSingleResolver {
                Asset.hermesDragIcon.swiftUIImage
                    .allowsHitTesting(false)
            }

            Text(resolver.location)
                .themeFont(.body(emphasised: false))
                .allowsHitTesting(false)

            Spacer()

            Button(role: .destructive, action: onDeleteAction) {
                Label("Delete", systemImage: "trash")
                    .foregroundStyle(.primary)
                    .labelStyle(.iconOnly)
                    .padding(.all, .themeSpacing6)
            }
            .buttonStyle(GhostButtonStyle())
        }
        .frame(maxWidth: .infinity)
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
            .background(Color(.background, .transparent))
            .themeBorder(style: .weak, cornerRadius: .radius12)
    }
}

// MARK: - Window

final class HermesWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
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
