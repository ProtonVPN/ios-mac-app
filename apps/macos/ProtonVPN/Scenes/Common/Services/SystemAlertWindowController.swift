//
//  Created on 14/07/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import AppKit
import Strings
import SwiftUI
import Theme
import VPNAppCore

/// A standalone window that looks and behaves like a SwiftUI alert.
///
/// Used when no regular window can host a native `.alert` sheet (status-menu popover frontmost, menu-bar-only mode, or
/// launch before any window exists). Unlike a sheet, it needs no host, so it can be sized and positioned before it is
/// ever shown.
final class SystemAlertWindowController: NSWindowController {
    /// Gap between the menu bar and the top of the alert.
    private static let topMargin: CGFloat = 8
    /// Minimum distance between the alert and the screen edges.
    private static let edgePadding: CGFloat = 8
    /// Fade duration for showing and closing.
    private static let fadeDuration: TimeInterval = 0.2

    private let alert: SystemAlert
    private let onClose: () -> Void

    /// - Parameter onClose: called exactly once, after the window is gone, however it was
    ///   dismissed (button, Escape, or `dismiss()`).
    init(alert: SystemAlert, onClose: @escaping () -> Void) {
        self.alert = alert
        self.onClose = onClose

        let panel = SystemAlertPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.hidesOnDeactivate = false
        // Keep the alert above normal windows so it isn't buried when the app deactivates; the popover still opens
        // above it (.popUpMenu outranks .floating).
        panel.level = .floating
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        // Match the status-menu popover (and how alerts rendered on the old sheet path); remove to follow the system
        // appearance instead.
        panel.appearance = NSAppearance(named: .darkAqua)

        super.init(window: panel)

        // The card resolves the tapped action from `alert.actions` at click time, so handlers swapped in by a re-push
        // (`updateOldAlert`) still apply.
        let card = SystemAlertCardView(
            title: alert.title,
            message: alert.message,
            actions: Self.presentedActions(of: alert).map { .init(title: $0.title, style: $0.style) },
            select: { [weak self] index in self?.select(index) }
        )
        let hosting = NSHostingController(rootView: card)
        panel.contentViewController = hosting
        panel.setContentSize(hosting.view.fittingSize)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Not implemented")
    }

    /// Shows the alert under the menu bar of the given screen, horizontally centered on `anchorMidX` (e.g. the status
    /// item), fixed to stay on screen. Falls back to the screen center when no anchor is given, and to the
    /// visible-frame center plus a small cascade offset so stacked alerts don't fully cover each other.
    func present(on screen: NSScreen?, anchorMidX: CGFloat?, cascadeIndex: Int) {
        guard let window else { return }

        if let visible = screen?.visibleFrame {
            let halfWidth = window.frame.width / 2
            let midX = min(
                max(anchorMidX ?? visible.midX, visible.minX + Self.edgePadding + halfWidth),
                visible.maxX - Self.edgePadding - halfWidth
            )
            let cascade = CGFloat(cascadeIndex) * 16
            window.setFrameOrigin(NSPoint(
                x: midX - halfWidth + cascade,
                // visibleFrame.maxY is the bottom edge of the menu bar.
                y: visible.maxY - Self.topMargin - window.frame.height - cascade
            ))
        } else {
            window.center()
        }

        window.alphaValue = 0
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            window.animator().alphaValue = 1
        }
    }

    /// Programmatic dismissal (e.g. auto-dismiss on connection); no handler is called.
    func dismiss() {
        fadeOutAndClose()
    }

    /// Replaces the alert's actions so a re-push swaps in fresh completion handlers.
    func update(actions: [AlertAction]) {
        alert.actions = actions
    }

    func bringToFront() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window?.makeKeyAndOrderFront(nil)
    }

    private func select(_ index: Int) {
        let actions = Self.presentedActions(of: alert)
        fadeOutAndClose { actions.indices.contains(index) ? actions[index].handler?() : () }
    }

    private func fadeOutAndClose(then handler: @escaping () -> Void = {}) {
        guard let window else {
            onClose()
            handler()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            window.animator().alphaValue = 0
        } completionHandler: { [self] in
            window.orderOut(nil)
            onClose()
            handler()
        }
    }

    private static func presentedActions(of alert: SystemAlert) -> [AlertAction] {
        alert.actions.isEmpty
            ? [AlertAction(title: Localizable.ok, style: .confirmative, handler: nil)]
            : alert.actions
    }
}

/// Borderless windows refuse key status by default; the alert needs it for keyboard handling (Return/Escape) and so
/// opening it closes the popover.
private final class SystemAlertPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

// MARK: - Card view

/// Recreates the look of a native SwiftUI alert. Metrics are matched by eye against the native panel on macOS 14+: 280
/// pt card, leading-aligned title and message, cancel on the left / default on the right, large capsule buttons, big
/// continuous corner radius.
private struct SystemAlertCardView: View {
    struct Action {
        let title: String
        let style: PrimaryActionType
    }

    let title: String?
    let message: String?
    let actions: [Action]
    let select: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing20) {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                if let title, !title.isEmpty {
                    Text(title)
                        .themeFont(.headline(emphasised: true))
                        .multilineTextAlignment(.leading)
                }
                if let message, !message.isEmpty {
                    Text(message)
                        .themeFont(.body(emphasised: true))
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            buttons
        }
        .padding(.themeSpacing16)
        .frame(width: Dimensions.suiAlertWidth)
        .background(BehindWindowBlur(material: .sheet, cornerRadius: Dimensions.suiAlertCornerRadius))
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Two buttons sit side by side (cancel left, default right, like the native alert); one or three-plus stack
    /// vertically with the default on top and cancel last.
    @ViewBuilder
    private var buttons: some View {
        if actions.count == 2 {
            HStack(spacing: .themeSpacing8) {
                ForEach(displayOrder, id: \.self) { index in
                    button(at: index).frame(maxWidth: .infinity)
                }
            }
        } else {
            VStack(spacing: .themeSpacing8) {
                ForEach(displayOrder, id: \.self) { index in
                    button(at: index).frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func button(at index: Int) -> some View {
        let action = actions[index]
        let isDefault = index == defaultActionIndex

        Button(role: action.style == .destructive ? .destructive : nil) {
            select(index)
        } label: {
            Text(action.title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AlertButtonStyle(isProminent: isDefault))
        .keyboardShortcut(shortcut(for: action, isDefault: isDefault))
    }

    /// The first confirmative action is the default (prominent, Return); if there is none,
    /// the last action is.
    private var defaultActionIndex: Int {
        actions.firstIndex { $0.style == .confirmative } ?? actions.indices.last ?? 0
    }

    /// Original indices in native display order: side-by-side puts the default on the right, while stacked puts the
    /// default first and cancel-style actions last.
    private var displayOrder: [Int] {
        let defaultIndex = defaultActionIndex
        var others = actions.indices.filter { $0 != defaultIndex }
        if actions.count == 2 {
            return others + [defaultIndex]
        }
        let cancels = others.filter { actions[$0].style == .cancel }
        others.removeAll { actions[$0].style == .cancel }
        return [defaultIndex] + others + cancels
    }

    private func shortcut(for action: Action, isDefault: Bool) -> KeyboardShortcut? {
        if action.style == .cancel {
            return .cancelAction
        }
        if isDefault {
            return .defaultAction
        }
        return nil
    }

    private enum Dimensions {
        static let suiAlertWidth: CGFloat = 260
        static let suiAlertCornerRadius: CGFloat = 20
    }
}

// MARK: - Behind-window blur

/// Blurs the screen content behind the window, like the native alert panel does. (SwiftUI Materials blend within the
/// window only; with nothing behind the card in this panel they render as a flat tint, so a real NSVisualEffectView in
/// behind-window mode is required.) Rounded corners are applied via the effect view's own mask image.
private struct BehindWindowBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let cornerRadius: CGFloat

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active // keep the blur when the window isn't key
        view.maskImage = .roundedCornerMask(radius: cornerRadius)
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}

private extension NSImage {
    /// A stretchable rounded-rect mask.
    static func roundedCornerMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

private struct AlertButtonStyle: ButtonStyle {
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body(emphasised: true))
            .padding(.vertical, .themeSpacing6)
            .padding(.horizontal, .themeSpacing12)
            .foregroundStyle(isProminent ? Color.white : Color.primary)
            .background(
                isProminent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
