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
    private let bar: ShellTabBar
    private let sheetController: ShellSheetController

    public init(store: StoreOf<TabularFeature>, pages pageControllers: [TabularFeature.Tab: UIViewController]) {
        let overlap = SheetOverlap()
        let sheetController = ShellSheetController(store: store, overlap: overlap)

        let pages = ShellPagesController()
        pages.setPages(pageControllers)
        pages.isModalInPresentation = true // the pages are the app, so the sheet never dismisses
        pages.view.backgroundColor = .backgroundColor()
        // The shell's alerts and covers launch from a permanent passenger beside the pages, the one seat that is
        // always in the hierarchy and always free to present.
        pages.install(passenger: UIHostingController(rootView: ShellDestinationsView(store: store)))

        // The system draws the bar; the sheet controller writes its contents from the store. Mounted once the
        // sheet is up.
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
            sheetController.observeShellState(sheet: sheet, pages: pages, bar: bar)
        }

        backdrop.present(pages, animated: false) { [backdrop, bar] in
            // Mounted once the sheet is up, so the bar goes in over the container it was presented into.
            backdrop.view.window.map { Self.mountBar(bar, in: $0) }
        }
    }

    /// Takes the shell's window attachments down for a logout: the bar out of the window, so the login screen that
    /// replaces the root is not left with it floating on top. The rest goes when the shell is released.
    public func dismantle() {
        bar.removeFromSuperview()
    }

    /// Lands an app-level flow on a tab: selects it, then pushes onto that tab's navigation stack.
    ///
    /// The push addresses the stack itself rather than whichever page is showing, so it neither needs the tab to be up
    /// already nor races the page swap the selection sets off a turn later. A controller of the same kind already on
    /// the stack is popped back to instead of pushed a second time, which is what these flows got from the window
    /// service's own stack push.
    public func push(_ viewController: UIViewController, onto tab: TabularFeature.Tab) {
        guard let navigation = pages.navigation(of: tab) else { return }
        store.send(.tabSelected(tab))
        if let existing = navigation.viewControllers.first(where: { type(of: $0) == type(of: viewController) }) {
            navigation.popToViewController(existing, animated: true)
        } else {
            navigation.pushViewController(viewController, animated: true)
        }
    }

    /// Mounts the bar's view along the window's bottom edge, in front of the pages sheet.
    ///
    /// Plain subview order is what puts it there: the caller mounts from the sheet's presentation completion, when the
    /// sheet's container is already in the window, so being added last is being added in front. A depth of its own
    /// would hold the bar over every later presentation too, and the paywall, onboarding and a page's own sheets all
    /// mount as containers beside it, where a bar floating on top is neither wanted nor usable. Re-mounting brings it
    /// forward again over a freshly presented sheet, which is the case order alone does not cover.
    private static func mountBar(_ barView: ShellTabBar, in window: UIWindow) {
        let isFirstMount = barView.superview !== window
        barView.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(barView)
        guard isFirstMount else { return }
        NSLayoutConstraint.activate([
            barView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            barView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            barView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
        ])
    }
}
