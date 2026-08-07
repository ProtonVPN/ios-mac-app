//
//  Created on 30/07/2026.
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

import UIKit

/// The shell's tab pages, one showing at a time. Can't be a UITabBar because that would require the elements to live in
/// the same sheet, which we can't do while also properly supporting detents (the tab living in a floating sheet has
/// some really weird UX characteristics when the detent gets flicked up + down).
public final class ShellPagesController: UIViewController {
    /// The pages by the tab each stands for. Which one shows is the store's selection, applied through `show`.
    private(set) var pages: [TabularFeature.Tab: UIViewController] = [:]

    /// The page currently showing. Services that need the visible tab's content, like the window's navigation
    /// stack lookup, read this where they would have read a tab bar controller's `selectedViewController`. The
    /// installed passenger is a permanent child, not a page, and is never returned here.
    public var shownPage: UIViewController? {
        children.first { child in pages.values.contains { $0 === child } }
    }

    /// The tab a page stands for, so a navigation stack's depth report can land on the tab it belongs to.
    func tab(of page: UIViewController) -> TabularFeature.Tab? {
        pages.first { $0.value === page }?.key
    }

    /// A tab's navigation stack, whether or not its page is the one showing. Pushing onto a stack whose view is out of
    /// the hierarchy is fine: selecting the tab brings the pushed page forward with it.
    func navigation(of tab: TabularFeature.Tab) -> UINavigationController? {
        pages[tab] as? UINavigationController
    }

    /// How much room the bar wants at the bottom edge beyond the safe area, so a page's content stops above it while
    /// its background still runs underneath. This is the inset a tab bar controller would have given these pages for a
    /// bar of its own.
    var barRoom: CGFloat = 0 {
        didSet {
            guard barRoom != oldValue else { return }
            additionalSafeAreaInsets.bottom = barRoom
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        // The app is compact-width everywhere, as it was when a tab bar controller carried these pages.
        traitOverrides.horizontalSizeClass = .compact
    }

    /// Takes the pages and shows the home tab.
    func setPages(_ pages: [TabularFeature.Tab: UIViewController]) {
        self.pages = pages
        show(.home)
    }

    /// Installs a permanent child beside the pages. It stays in the hierarchy while the pages swap, takes no
    /// space, and receives no touches. The shell's modal presentations anchor here, because a page leaves the
    /// hierarchy with its tab and the backdrop under the sheet can never present (see `ShellDestinationsView`).
    func install(passenger: UIViewController) {
        addChild(passenger)
        passenger.view.frame = .zero
        passenger.view.backgroundColor = nil
        passenger.view.isUserInteractionEnabled = false
        view.insertSubview(passenger.view, at: 0)
        passenger.didMove(toParent: self)
    }

    /// Guards against dismissing the main sheet by accident.
    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard let closing = presentedViewController, !closing.isBeingDismissed else {
            completion?()
            return
        }
        super.dismiss(animated: flag, completion: completion)
    }

    /// Shows `tab`'s page, if it has one and it is not already showing.
    func show(_ tab: TabularFeature.Tab) {
        guard let page = pages[tab], page !== shownPage else { return }
        for shown in children where pages.values.contains(where: { $0 === shown }) {
            shown.willMove(toParent: nil)
            shown.view.removeFromSuperview()
            shown.removeFromParent()
        }
        addChild(page)
        page.view.frame = view.bounds
        page.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(page.view)
        page.didMove(toParent: self)
    }
}
