//
//  ConnectingViewController.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa
import ComposableArchitecture
import Connection
import Strings
import SwiftUI
import Theme

@MainActor
class ConnectingViewController: NSViewController {
    private let store: StoreOf<ConnectingOverlayFeature>
    private var hostingView: NSHostingView<ConnectingOverlayContentView>!

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    required init(store: StoreOf<ConnectingOverlayFeature>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: Dimensions.rootViewWidth, height: Dimensions.rootViewHeight))
        rootView.translatesAutoresizingMaskIntoConstraints = false
        view = rootView

        hostingView = NSHostingView(rootView: ConnectingOverlayContentView(store: store))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: rootView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityModal(true)
    }

    private enum Dimensions {
        static let rootViewWidth: CGFloat = 444
        static let rootViewHeight: CGFloat = 561
    }
}

private struct ConnectingOverlayContentView: View {
    @Bindable var store: StoreOf<ConnectingOverlayFeature>

    var body: some View {
        let buttons = overlayButtons

        VStack(spacing: .themeSpacing32) {
            ConnectingOverlayGraphicView(graphicKind: store.graphicKind)
                .frame(.square(Dimensions.graphicSize))

            if !store.hidePhase {
                Text(AttributedString(firstString))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Text(AttributedString(secondString))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, .themeSpacing8)

            VStack(spacing: .themeSpacing16) {
                ForEach(buttons) { button in
                    ConnectingOverlayButtonView(title: button.title, style: button.style) {
                        store.send(.buttonTapped(button.kind))
                    }
                    .frame(minWidth: Dimensions.buttonMinWidth)
                    .frame(height: Dimensions.buttonHeight)
                }
            }
        }
        .frame(width: Dimensions.contentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var overlayButtons: [ConnectingOverlayButtonModel] {
        if store.timedOut {
            return store.isIkeWithKsEnabled ? [.retryWithoutKillSwitch, .cancel] : [.retry, .cancel]
        }
        return store.displayState.is(\.connected) ? [.done] : [.cancel]
    }

    private var firstString: NSAttributedString {
        if store.displayState.is(\.connected) {
            return Localizable.successfullyConnected.styled(font: .themeFont(.small))
        }
        let value = store.isReconnecting ? Localizable.youAreNotProtected : Localizable.initializingConnection
        return value.styled(font: .themeFont(.small))
    }

    private var secondString: NSAttributedString {
        if store.timedOut {
            return timedOutSecondString
        }

        let resolvedServer = store.displayState.resolvedServer
        let boldString = resolvedServer.map { server in
            Self.styledServerName(country: server.logical.country, name: server.logical.name)
        } ?? ""
        let string: String = switch store.displayState {
        case .connected:
            Localizable.connectedToVpn(boldString)
        case .disconnected:
            store.isReconnecting ? Localizable.reconnecting : Localizable.preparingConnection
        case .resolving, .connecting, .disconnecting:
            if store.isReconnecting {
                Localizable.reconnecting
            } else if boldString.isEmpty {
                Localizable.preparingConnection
            } else {
                Localizable.connectingTo(boldString)
            }
        }

        let attributedString = NSMutableAttributedString(attributedString: string.styled(font: .themeFont(.heading2)))
        if !boldString.isEmpty, let stringRange = string.range(of: boldString) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(.font, value: NSFont.themeFont(.heading2, bold: true), range: range)
        }
        return attributedString
    }

    private var timedOutSecondString: NSAttributedString {
        let boldString = Localizable.connectionTimedOutBold
        if !store.isIkeWithKsEnabled {
            let string = Localizable.connectionTimedOut
            let attributedString = NSMutableAttributedString(attributedString: string.styled(font: .themeFont(.heading2)))
            if let stringRange = string.range(of: boldString) {
                let range = NSRange(stringRange, in: string)
                attributedString.addAttribute(.font, value: NSFont.themeFont(.heading2, bold: true), range: range)
            }
            return attributedString
        }

        let description = "\n\n" + Localizable.timeoutKsIkeDescritpion
        let string = Localizable.connectionTimedOut + description
        let attributedString = NSMutableAttributedString(attributedString: string.styled(font: .themeFont(.heading2)))
        if let stringRange = string.range(of: boldString) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(.font, value: NSFont.themeFont(.heading2, bold: true), range: range)
        }
        if let descriptionRange = string.range(of: description) {
            let range = NSRange(descriptionRange, in: string)
            attributedString.addAttribute(.font, value: NSFont.themeFont(.small), range: range)
        }
        return attributedString
    }

    private static func styledServerName(country: String, name: String) -> String {
        (country + " " + name)
            .replacingOccurrences(of: " ", with: "\u{00A0}")
            .replacingOccurrences(of: "-", with: "\u{2011}")
    }

    private enum Dimensions {
        static let graphicSize: CGFloat = 120
        static let contentWidth: CGFloat = 340
        static let buttonMinWidth: CGFloat = 120
        static let buttonHeight: CGFloat = 40
    }
}

private struct ConnectingOverlayButtonView: View {
    let title: String
    let style: ConnectingOverlayButtonVisualStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(ConnectingOverlayButtonStyle(style: style))
    }
}

private struct ConnectingOverlayGraphicView: View {
    let graphicKind: ConnectingOverlayFeature.State.GraphicKind

    var body: some View {
        switch graphicKind {
        case .loading:
            ConnectingOverlayLoadingFramesView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .connected:
            Image(nsImage: Theme.Asset.vpnResultConnected.image)
                .resizable()
                .interpolation(.high)
                .frame(.square(Dimensions.connectedImageSize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .warning:
            Image(nsImage: Theme.Asset.vpnResultWarning.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private enum Dimensions {
        static let connectedImageSize: CGFloat = 105
    }
}

private struct ConnectingOverlayLoadingFramesView: View {
    @State private var currentFrame = 0

    private static let frameRate: TimeInterval = 1 / 45
    private static let frames: [NSImage] = {
        guard let urls = Bundle(for: ConnectingViewController.self)
            .urls(forResourcesWithExtension: "png", subdirectory: "LoadingAnimationFrames")
        else {
            return []
        }

        return urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { NSImage(contentsOf: $0) }
    }()

    private let timer = Timer.publish(every: frameRate, on: .main, in: .common).autoconnect()

    var body: some View {
        if Self.frames.isEmpty {
            ProgressView()
                .controlSize(.large)
        } else {
            Image(nsImage: Self.frames[currentFrame])
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .onReceive(timer) { _ in
                    currentFrame = (currentFrame + 1) % Self.frames.count
                }
        }
    }
}

private struct ConnectingOverlayButtonStyle: ButtonStyle {
    let style: ConnectingOverlayButtonVisualStyle

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.themeFont(.title3()))
            .foregroundStyle(Color(.text, .normal))
            .padding(.horizontal, .themeSpacing16)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                    .stroke(borderColor, lineWidth: 2)
            )
            .onHover { isHovered = $0 }
            .linkPointer()
    }

    private var backgroundColor: Color {
        switch style {
        case .interactive:
            Color(.background, isHovered ? [.interactive, .hovered] : [.interactive])
        case .normal:
            Color(.background, isHovered ? [.transparent, .hovered] : [.transparent])
        }
    }

    private var borderColor: Color {
        switch style {
        case .interactive:
            Color(.border, isHovered ? [.interactive, .hovered] : [.interactive])
        case .normal:
            Color(.border, .normal)
        }
    }
}

private enum ConnectingOverlayButtonVisualStyle {
    case normal
    case interactive
}

private struct ConnectingOverlayButtonModel: Identifiable {
    let kind: ConnectingOverlayFeature.ButtonKind
    let title: String
    let style: ConnectingOverlayButtonVisualStyle

    var id: ConnectingOverlayFeature.ButtonKind {
        kind
    }

    static var cancel: Self {
        .init(kind: .cancel, title: Localizable.cancel, style: .normal)
    }

    static var done: Self {
        .init(kind: .done, title: Localizable.done, style: .normal)
    }

    static var retry: Self {
        .init(kind: .retry, title: Localizable.tryAgain, style: .normal)
    }

    static var retryWithoutKillSwitch: Self {
        .init(kind: .retryWithoutKillSwitch, title: Localizable.tryAgainWithoutKillswitch, style: .interactive)
    }
}
