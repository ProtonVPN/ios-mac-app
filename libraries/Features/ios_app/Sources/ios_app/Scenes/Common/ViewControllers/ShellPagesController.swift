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

import Ergonomics
import UIKit

/// The shell's tab pages, one showing at a time. This is what the sheet carries.
///
/// It is deliberately not a `UITabBarController`: the bar that chooses between these pages lives in the window instead
/// (see `ShellTabBar`). A bar inside the sheet is laid out against a frame the sheet animates, and while a drag keeps
/// the two in step, a release does not. The sheet's frame and the bar's offset within it settle on separate curves, so
/// the bar leaps most of the way up the screen in the first frame and eases back down over the rest of the animation.
/// Nothing in the window resizes the bar, so there is no second animation for it to disagree with, and what stays in
/// the sheet is the pages alone.
final class ShellPagesController: UIViewController {
    /// The pages, in the shell's tab order.
    private(set) var pages: [UIViewController] = []

    /// The page currently showing, for services that address the visible tab's content: the window's navigation stack
    /// lookup asks this the question a tab bar controller used to answer with `selectedViewController`. Only pages
    /// count; the installed passenger is a permanent child and never the answer.
    var shownPage: UIViewController? {
        children.first(where: pages.contains)
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

    /// The bar items the pages declare, in the same order, for the bar to show. A page that is a navigation stack
    /// answers with its root's, which is where the legacy pages set theirs.
    var barItems: [UITabBarItem] {
        pages.map { page in
            ((page as? UINavigationController)?.viewControllers.first ?? page).tabBarItem
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The app is compact-width everywhere, as it was when a tab bar controller carried these pages.
        traitOverrides.horizontalSizeClass = .compact
    }

    /// Takes the pages and shows the first of them.
    func setPages(_ pages: [UIViewController]) {
        self.pages = pages
        show(pageAt: 0)
    }

    /// Seats a permanent passenger beside the pages: it stays in the hierarchy while they swap, and takes no space
    /// and no touches. The shell's modal launcher rides here, since a page leaves the hierarchy with its tab and the
    /// backdrop below the sheet is never free to present (see `ShellDestinationsView`).
    func install(passenger: UIViewController) {
        addChild(passenger)
        passenger.view.frame = .zero
        passenger.view.backgroundColor = nil
        passenger.view.isUserInteractionEnabled = false
        view.insertSubview(passenger.view, at: 0)
        passenger.didMove(toParent: self)
    }

    /// Shows the page at `index`, if there is one there and it is not already showing. Out-of-range indices are
    /// ignored, so a bar selection may be passed straight through.
    func show(pageAt index: Int) {
        guard let page = pages[safe: index], page !== shownPage else { return }
        for shown in children where pages.contains(shown) {
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
