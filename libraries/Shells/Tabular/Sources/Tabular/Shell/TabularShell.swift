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

/// The tabular shell, assembled: the globe backdrop as the window root, the tab pages presented over it in a
/// sheet, the bar mounted in the window, and the sheet controller keeping sheet, pages, and bar in agreement
/// with the store.
///
/// The app builds the store and the four page controllers, because the services and storyboards they need are in
/// the app. The shell manages everything below that. Presenting again is harmless, which is how flows that
/// replace the window root (onboarding, the paywall) return the shell afterwards.
@MainActor
public final class TabularShell {
    /// The app's main store, built by the app and adopted here.
    public let store: StoreOf<TabularFeature>

    /// The coverage channel between the sheet controller and the views that track the sheet. Per-shell, so the last
    /// login's final sheet position cannot show through the first frames of the next one.
    private let overlap: SheetOverlap
    private let backdrop: UIViewController
    private let pages: ShellPagesController
    private let bar: ShellTabBar
    private let sheetController: ShellSheetController

    public init(store: StoreOf<TabularFeature>, pages pageControllers: [TabularFeature.Tab: UIViewController]) {
        let overlap = SheetOverlap()
        let sheetController = ShellSheetController(store: store, overlap: overlap)

        let pages = ShellPagesController()
        pages.setPages(pageControllers)
        pages.isModalInPresentation = true // the pages are the app, so the sheet never dismisses
        pages.view.backgroundColor = .backgroundColor()
        // The shell's alerts and covers launch from a permanent passenger beside the pages, the one seat that is always
        // in the hierarchy and always free to present.
        pages.install(passenger: UIHostingController(rootView: ShellDestinationsView(store: store)))

        // The system draws the bar; the sheet controller writes its contents from the store.
        let bar = ShellTabBar()
        bar.delegate = sheetController
        // The pages keep their content clear of the bar they do not contain. This is a measurement rather than a
        // constant the shell could declare: on iOS 26 the system decides the floating bar's height.
        bar.onRoomChange = { [weak pages] room in pages?.barRoom = room }

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
        self.bar = bar
        self.sheetController = sheetController
    }

    /// Puts the shell in front: roots the backdrop through `makeRoot`, presents the pages sheet over it, and
    /// mounts the bar in the window. A root swap tears some of these attachments down and leaves others, so each one
    /// is redone only if it is missing. Calling this while the shell is already up does nothing.
    ///
    /// - Parameter didPresent: Called once the shell is on screen and able to present anything else over itself.
    ///   The sheet goes up asynchronously, so a modal asked for on the line after this method returns arrives while
    ///   that presentation is still in flight, and UIKit drops it.
    public func present(rootedBy makeRoot: (UIViewController) -> Void, didPresent: (() -> Void)? = nil) {
        if backdrop.view.window == nil {
            makeRoot(backdrop)
            // Keep the app compact-width everywhere for now; this keeps the bottom sheet working on iPad.
            backdrop.view.window?.traitOverrides.horizontalSizeClass = .compact
        }
        guard pages.presentingViewController == nil else {
            // Already up, so it can be presented over right away.
            didPresent?()
            return
        }

        // UIKit builds a fresh sheet controller for each presentation, so the ladder is configured per present.
        if let sheet = pages.sheetPresentationController {
            sheet.delegate = sheetController
            // One fixed detent list for every tab; only the selection moves, applied by the sheet controller.
            sheet.detents = TabularFeature.Detent.allCases.map(\.sheetDetent)
            sheet.largestUndimmedDetentIdentifier = TabularFeature.Detent.allCases.last?.identifier
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersGrabberVisible = true
            // On a window wider than the pages' content column the sheet stops at the column's width
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
            sheetController.observeShellState(sheet: sheet, pages: pages, bar: bar)
        }

        backdrop.present(pages, animated: false) { [backdrop, pages, bar] in
            // Mounted once the sheet is up, so the bar goes in over the container it was presented into.
            backdrop.view.window.map { Self.mountBar(bar, in: $0, matching: pages.view) }
            didPresent?()
        }
    }

    /// Takes the shell's window attachments down for a logout: the bar out of the window, so the login screen that
    /// replaces the root is not left with it floating on top. The rest goes when the shell is released.
    public func dismantle() {
        bar.removeFromSuperview()
    }

    /// Sends an app-level flow to a tab: selects the tab, then pushes onto that tab's navigation stack.
    ///
    /// The push goes to the stack directly rather than to whichever page is visible, so it does not need the tab to
    /// be showing yet and cannot race the page swap that the selection causes one turn later. A controller of the
    /// same type already on the stack is popped back to instead of pushed a second time.
    public func push(_ viewController: UIViewController, onto tab: TabularFeature.Tab) {
        guard let navigation = pages.navigation(of: tab) else { return }
        store.send(.tabSelected(tab))
        if let existing = navigation.viewControllers.first(where: { type(of: $0) == type(of: viewController) }) {
            navigation.popToViewController(existing, animated: true)
        } else {
            navigation.pushViewController(viewController, animated: true)
        }
    }

    /// Mounts the bar along the window's bottom edge, in front of the pages sheet.
    ///
    /// Plain subview order is what keeps it in front: mounting runs in the sheet's presentation completion, when the
    /// sheet's container is already in the window, so the bar added last sits above it. The bar gets no window or
    /// layer depth of its own on purpose: the paywall, onboarding, and page sheets present in containers beside it
    /// and must cover it. Re-mounting after such a presentation brings the bar back to the front, which subview
    /// order alone would not do.
    ///
    /// Only the bar's position is pinned here; the bar holds its own height at its fitting height (see
    /// `ShellTabBar.heightConstraint`).
    ///
    /// Width differs by OS. On iOS 26 the bar spans the window and the system floats its material inside that span
    /// at a size of its own choosing. Before iOS 26 the bar's bounds are the bar — background, items, everything — so
    /// it matches the pages instead: pinned to the width the sheet actually resolved, not the width the pages asked
    /// for, because the system may grant less than `preferredContentSize` (and did, on iPad). Constraining to the
    /// pages' view is legal here because mounting runs after the presentation completes, when bar and pages share
    /// the window as an ancestor, and it keeps tracking through rotations and re-resolutions for free. On windows
    /// the sheet spans fully, the bar spans fully with it, which is the iPhone behavior unchanged.
    private static func mountBar(_ barView: ShellTabBar, in window: UIWindow, matching pagesView: UIView) {
        // Read before `addSubview`, which is what makes the answer mean "first mount": constraints between the bar
        // and the window (and the pages) die with `removeFromSuperview` on logout, so a remount must rebuild them.
        let isFirstMount = barView.superview !== window
        barView.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(barView)
        guard isFirstMount else { return }
        var constraints = [barView.bottomAnchor.constraint(equalTo: window.bottomAnchor)]
        if #available(iOS 26.0, *) {
            constraints += [
                barView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                barView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            ]
        } else {
            constraints += [
                barView.centerXAnchor.constraint(equalTo: pagesView.centerXAnchor),
                barView.widthAnchor.constraint(equalTo: pagesView.widthAnchor),
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }
}
