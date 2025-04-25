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
import Sharing
import Theme

struct HermesView: ExplicitlySizedView {
    static let viewSize: CGSize = .init(width: 752, height: 600)

    // TODO: Fix build issues and put back as @Bindable
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
                        Text("Hermes")
                            .themeFont(.title3(emphasised: true))
                            .foregroundStyle(Color.white)
                        Text("Connect to VPN with a self-hosted or third-party Hermes system. Learn more...")
                            .themeFont(.body(emphasised: false))
                            .foregroundStyle(Color(.text, .weak))
                    }

                    Spacer()

                    Toggle(isOn: isEnabledBinding) { EmptyView() }
                        .onSubmit { isEnabledBinding.wrappedValue = !isEnabledBinding.wrappedValue }
                        .toggleStyle(.switch)
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
        .padding(.vertical, 24.0)
        .padding(.horizontal, 40.0)
        .frame(width: Self.viewSize.width, height: Self.viewSize.height, alignment: .top)
        .background(Color(red: 22 / 255, green: 20 / 255, blue: 28 / 255))
    }

    @ViewBuilder
    private var resolversContent: some View {
        let resolvers = viewModel.activeHermesResolvers

        Text("Servers (\(resolvers.count))")
            .themeFont(.callout(emphasised: false))
            .foregroundStyle(Color(.text, .weak))
            .padding(.top, 24.0)

        VStack(alignment: .leading, spacing: 8.0) {
            Text("Add new Hermes Resolver")
                .themeFont(.title3(emphasised: true))
                .foregroundStyle(Color(.text, .normal))

            locationInputView

            locationValidationView

            Text("If your custom Hermes Resolver doesn’t work, the standard Proton Hermes Resolver will be used.")
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color(.text, .hint))

            resolversListView
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16.0)
        .padding(.vertical, 24.0)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12.0, style: .continuous))
        .onChange(of: resolverLocation) { newValue in
            resolverLocationValidation = viewModel.validate(location: newValue)
        }
    }

    private var locationInputView: some View {
        HStack {
            TextField("192.0.2.0", text: $resolverLocation)
                .onSubmit { submitResolverLocation() }
                .focused($locationTextFieldIsFocused)
                .overlay(locationTextFieldIsFocused ? resolverLocationOverlay : nil)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            Button("Add") {
                submitResolverLocation()
            }
            .disabled(resolverLocationValidation == .empty)
            .buttonStyle(PrimaryButtonStyle(size: .init(width: 58.0, height: 32.0)))
        }
    }

    private var resolverLocationOverlay: some View {
        switch resolverLocationValidation {
        case .empty, .valid:
            return RoundedRectangle(cornerRadius: 16).stroke(Color.purple)
        case .invalid, .duplicate, .unexpectedError:
            return RoundedRectangle(cornerRadius: 16).stroke(Color.red)
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
            Text("Enter the server’s IPv4 address")
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color(.text, .weak))
        case .invalid:
            Text("Enter a valid IPv4 address")
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color.red)
        case .duplicate:
            Text("Server already added")
                .themeFont(.callout(emphasised: false))
                .foregroundStyle(Color.red)
        case .unexpectedError:
            Text("An unexpected error occured")
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
                    .help("Double click to copy")
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

            Spacer()

            #if DEBUG
            testerView(with: resolver.location)
            #endif

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

    private enum HitTesting {
        case none
        case inProgress
        case result(Bool)
    }

    @State private var hitTest: HitTesting = .none

    @ViewBuilder
    private func testerView(with location: String) -> some View {
        switch hitTest {
        case .none:
            Button {
                Task {
                    await MainActor.run { hitTest = .inProgress }
                    let result = await viewModel.tlsHitTest(location)
                    await MainActor.run { hitTest = .result(result) }
                }
            } label: {
                Label("Test", systemImage: "network")
                    .foregroundStyle(.primary)
                    .labelStyle(.iconOnly)
            }
        case .inProgress:
            ProgressView()
        case .result(let succeeded):
            Group {
                if succeeded {
                    Color.green
                } else {
                    Color.red
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(2))
                hitTest = .none
            }
        }
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
            .padding(.horizontal, 16.0)
            .padding(.vertical, 24.0)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12.0, style: .continuous))
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

        title = "Hermes Feature" // TODO: Localize
        titlebarAppearsTransparent = true
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .color(.background, .weak)
    }
}
