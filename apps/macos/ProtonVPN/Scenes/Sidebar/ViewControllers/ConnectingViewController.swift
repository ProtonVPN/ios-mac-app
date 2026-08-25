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
    private var mouseTrackingMonitor: Any?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    required init(store: StoreOf<ConnectingOverlayFeature>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        if let mouseTrackingMonitor {
            NSEvent.removeMonitor(mouseTrackingMonitor)
        }
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

    override func viewDidAppear() {
        super.viewDidAppear()
        installMouseTrackingBarrier()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        removeMouseTrackingBarrier()
    }

    /// SwiftUI's `.onHover` (used by sidebar/countries rows beneath the overlay) is backed by
    /// `NSTrackingArea` with `.inVisibleRect` — which dispatches mouseEntered/mouseExited based
    /// purely on the cursor's geometric position in the owning view's rect, regardless of view
    /// occlusion or hit-testing. Subclassing `NSView`, claiming hit-tests, adding tracking areas,
    /// or applying SwiftUI `.contentShape` modifiers on the overlay all leave that dispatch
    /// untouched. The only way to stop it from inside the overlay is to drop the relevant
    /// `NSEvent`s before AppKit dispatches them. Buttons inside the overlay forgo hover styling
    /// while presented as a side effect — clicks still work.
    private func installMouseTrackingBarrier() {
        guard mouseTrackingMonitor == nil, let window = view.window else { return }
        mouseTrackingMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .mouseEntered, .mouseExited]
        ) { [weak window] event in
            event.window === window ? nil : event
        }
    }

    private func removeMouseTrackingBarrier() {
        guard let monitor = mouseTrackingMonitor else { return }
        NSEvent.removeMonitor(monitor)
        mouseTrackingMonitor = nil
    }

    private enum Dimensions {
        static let rootViewWidth: CGFloat = 444
        static let rootViewHeight: CGFloat = 561
    }
}

private struct ConnectingOverlayContentView: View {
    @Bindable var store: StoreOf<ConnectingOverlayFeature>

    var body: some View {
        VStack(spacing: .themeSpacing32) {
            ConnectingOverlayGraphicView(graphicKind: store.graphicKind)
                .frame(.square(Dimensions.graphicSize))

            if !store.hidePhase {
                Text(AttributedString(ConnectingOverlayPhaseFormatter.headline(for: store.headlinePhase)))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Text(AttributedString(ConnectingOverlayPhaseFormatter.body(for: store.bodyPhase)))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, .themeSpacing8)

            VStack(spacing: .themeSpacing16) {
                ForEach(overlayButtons) { button in
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
            Theme.Asset.vpnResultConnected.swiftUIImage
                .resizable()
                .interpolation(.high)
                .frame(.square(Dimensions.connectedImageSize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .warning:
            Theme.Asset.vpnResultWarning.swiftUIImage
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private enum Dimensions {
        static let connectedImageSize: CGFloat = 105
    }
}

/// Plays the loading animation for as long as the overlay is on screen.
private struct ConnectingOverlayLoadingFramesView: View {
    @State private var frames: [NSImage] = []

    private static let frameDuration: TimeInterval = 1 / 45

    var body: some View {
        Group {
            if frames.isEmpty {
                ProgressView()
                    .controlSize(.large)
            } else {
                TimelineView(.animation(minimumInterval: Self.frameDuration)) { context in
                    Image(nsImage: frames[frameIndex(at: context.date)])
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                }
            }
        }
        .task {
            frames = await Task.detached(priority: .userInitiated) { loadFrames() }.value
        }
        .onDisappear {
            frames = []
        }
    }

    private func frameIndex(at date: Date) -> Int {
        let elapsed = date.timeIntervalSinceReferenceDate
        return Int(elapsed / Self.frameDuration) % frames.count
    }
}

private func loadFrames() -> [NSImage] {
    guard let urls = Bundle(for: ConnectingViewController.self)
        .urls(forResourcesWithExtension: "png", subdirectory: "LoadingAnimationFrames")
    else {
        return []
    }

    return urls
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .compactMap { NSImage(contentsOf: $0) }
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

private enum ConnectingOverlayPhaseFormatter {
    static func headline(for phase: ConnectingOverlayFeature.State.HeadlinePhase) -> NSAttributedString {
        let string: String = switch phase {
        case .connected: Localizable.successfullyConnected
        case .initializing: Localizable.initializingConnection
        }
        return string.styled(font: .themeFont(.small))
    }

    static func body(for phase: ConnectingOverlayFeature.State.BodyPhase) -> NSAttributedString {
        switch phase {
        case let .timedOut(isIkeWithKsEnabled):
            return timedOut(isIkeWithKsEnabled: isIkeWithKsEnabled)
        case let .connected(serverName):
            let bold = styled(serverName: serverName)
            return body(string: Localizable.connectedToVpn(bold), bold: bold)
        case let .connecting(serverName):
            let bold = styled(serverName: serverName)
            return body(string: Localizable.connectingTo(bold), bold: bold)
        case .preparing:
            return body(string: Localizable.preparingConnection, bold: "")
        }
    }

    private static func body(string: String, bold: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: string.styled(font: .themeFont(.heading2)))
        if !bold.isEmpty, let stringRange = string.range(of: bold) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(.font, value: NSFont.themeFont(.heading2, bold: true), range: range)
        }
        return attributedString
    }

    private static func timedOut(isIkeWithKsEnabled: Bool) -> NSAttributedString {
        let boldString = Localizable.connectionTimedOutBold
        if !isIkeWithKsEnabled {
            return body(string: Localizable.connectionTimedOut, bold: boldString)
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

    private static func styled(serverName: ConnectingOverlayFeature.State.ServerName) -> String {
        (serverName.country + " " + serverName.name)
            .replacingOccurrences(of: " ", with: "\u{00A0}")
            .replacingOccurrences(of: "-", with: "\u{2011}")
    }
}

private struct ConnectingOverlayButtonModel: Identifiable {
    let kind: ConnectingOverlayFeature.ButtonKind
    let title: String
    let style: ConnectingOverlayButtonVisualStyle

    var id: ConnectingOverlayFeature.ButtonKind {
        kind
    }

    static let cancel: Self = .init(kind: .cancel, title: Localizable.cancel, style: .normal)

    static let done: Self = .init(kind: .done, title: Localizable.done, style: .normal)

    static let retry: Self = .init(kind: .retry, title: Localizable.tryAgain, style: .normal)

    static let retryWithoutKillSwitch: Self = .init(kind: .retryWithoutKillSwitch, title: Localizable.tryAgainWithoutKillswitch, style: .interactive)
}
