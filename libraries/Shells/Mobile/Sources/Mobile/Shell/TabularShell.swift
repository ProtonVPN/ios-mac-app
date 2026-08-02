//
//  Created on 02/08/2026.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import SwiftUI
import Theme
import UIKit

/// The tabular shell, assembled: the globe backdrop at the window's root, the tab pages presented over it in their
/// sheet, the bar mounted in the window, and the sheet controller keeping all of them agreeing with the store.
///
/// The app builds the store and the four page controllers, which is where its services and storyboards live; the
/// shell owns everything from there down. Presenting is safe to repeat, which is what lets flows that replace the
/// window root (onboarding, the paywall) borrow it and give it back.
@MainActor
public final class TabularShell {
    /// The app's main store, built by the app and adopted here.
    public let store: StoreOf<TabularFeature>

    /// The coverage channel between the sheet controller and the views that track the sheet. Per-shell, so the last
    /// login's final sheet position cannot show through the first frames of the next one.
    private let overlap: SheetOverlap
    private let backdrop: UIViewController
    private let pages: ShellPagesController
    private let barHost: UIViewController
    private let sheetController: ShellSheetController

    public init(store: StoreOf<TabularFeature>, pages pageControllers: [TabularFeature.Tab: UIViewController]) {
        let overlap = SheetOverlap()
        let sheetController = ShellSheetController(store: store, overlap: overlap)

        let pages = ShellPagesController()
        pages.setPages(pageControllers)
        pages.isModalInPresentation = true // the pages are the app, so the sheet never dismisses
        pages.view.backgroundColor = .backgroundColor()
        // The pages keep their content clear of the bar they do not contain.
        pages.barRoom = ShellTabBarView.contentHeight
        // The shell's alerts and covers launch from a permanent passenger beside the pages, the one seat that is
        // always in the hierarchy and always free to present.
        pages.install(passenger: UIHostingController(rootView: ShellDestinationsView(store: store)))

        // The bar renders itself from the store and the coverage channel; its view is mounted once the sheet is up.
        let barHost = UIHostingController(rootView: ShellTabBarView(store: store, overlap: overlap))
        barHost.sizingOptions = .intrinsicContentSize
        barHost.view.backgroundColor = .clear

        // The UIKit tabs' navigation stacks report their depth through the sheet controller, so a pushed legacy page
        // can hold the sheet at full, and ask it for the room before pushing into it.
        for (tab, page) in pageControllers {
            guard let navigation = page as? UINavigationController else { continue }
            navigation.delegate = sheetController
            (navigation as? SheetNavigationController)?.makeRoomForPush = { [weak sheetController] push in
                guard let sheetController else {
                    push()
                    return
                }
                sheetController.makeRoom(for: tab, thenPush: push)
            }
        }
        sheetController.trackSheetHeight(of: pages)

        self.store = store
        self.overlap = overlap
        self.backdrop = UIHostingController(rootView: TabularBackdropView(store: store, overlap: overlap))
        self.pages = pages
        self.barHost = barHost
        self.sheetController = sheetController
    }

    /// Puts the shell in front: the backdrop rooted through `makeRoot`, the pages in their sheet over it, and the bar
    /// mounted in the window the rooting placed it in. Everything survives a root swap except those three
    /// attachments, so each is re-done only where a swap tore it down, and calling this with the shell already up
    /// finds nothing to do.
    public func present(rootedBy makeRoot: (UIViewController) -> Void) {
        if backdrop.view.window == nil {
            makeRoot(backdrop)
            // Keep the app compact-width everywhere for now; this keeps the bottom sheet working on iPad.
            backdrop.view.window?.traitOverrides.horizontalSizeClass = .compact
        }
        guard pages.presentingViewController == nil else { return }

        // UIKit builds a fresh sheet controller for each presentation, so the ladder is configured per present.
        if let sheet = pages.sheetPresentationController {
            sheet.delegate = sheetController
            // One fixed ladder for every tab; only the selection moves, applied by the sheet controller.
            sheet.detents = TabularFeature.Detent.allCases.map(\.sheetDetent)
            sheet.largestUndimmedDetentIdentifier = TabularFeature.Detent.allCases.last?.identifier
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersGrabberVisible = true
            sheetController.observeShellState(sheet: sheet, pages: pages)
        }

        backdrop.present(pages, animated: false) { [backdrop, barHost] in
            // Mounted once the sheet is up, so the bar goes in over the container it was presented into.
            backdrop.view.window.map { Self.mountBar(barHost.view, in: $0) }
        }
    }

    /// Takes the shell's window attachments down for a logout: the bar out of the window, so the login screen that
    /// replaces the root is not left with it floating on top. The rest goes when the shell is released.
    public func dismantle() {
        barHost.view.removeFromSuperview()
    }

    /// Mounts the bar's view along the window's bottom edge, over everything else the window shows. Mounting again in
    /// the same window is a no-op, so a re-presented sheet can pass through here.
    private static func mountBar(_ barView: UIView, in window: UIWindow) {
        guard barView.superview !== window else { return }
        barView.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(barView)
        // A presented sheet mounts in a container that is this view's sibling, so being added last is not enough to
        // stay in front of it.
        barView.layer.zPosition = Dimensions.barOverlayDepth
        NSLayoutConstraint.activate([
            barView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            barView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            barView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
        ])
    }
}

/// The bar mount's fixed geometry.
private enum Dimensions {
    /// Far enough in front of the window's other children that the sheet's presentation container, which carries no
    /// depth of its own, cannot come between the bar and the user.
    static let barOverlayDepth: CGFloat = 1000
}
