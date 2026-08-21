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

import Theme
import UIKit

/// The shell's tab bar, mounted in the window rather than in the sheet the pages ride in, since the tab bar behaves
/// strangely when flicking the detent sheet up + down otherwise.
final class ShellTabBar: UITabBar {
    /// Reports the room the bar wants above the safe area, so the pages behind it can keep their content clear of it.
    /// Called from layout, since only layout knows what the height settled at.
    var onRoomChange: ((CGFloat) -> Void)?

    private let tabItems = TabularFeature.Tab.allCases.map { ShellTabBarItem(tab: $0) }

    /// The room reported last, so the pages hear about the height once per change rather than once per layout pass.
    private var lastReportedRoom: CGFloat?

    /// The bar's height, kept equal to `sizeThatFits` by `updateHeight`. Owned by the bar itself so it survives the
    /// unmount + remount that a logout causes; constraints to the window do not.
    ///
    /// One notch below required, so that a transient system layout (the encapsulated frames UIKit imposes
    /// mid-presentation and mid-rotation) breaks nothing and the bar snaps back the next pass.
    private lazy var heightConstraint: NSLayoutConstraint = {
        let constraint = heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = .required - 1
        return constraint
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyAppearance()
        heightConstraint.isActive = true
        updateHeight()
        registerForTraitChanges([UITraitVerticalSizeClass.self, UITraitPreferredContentSizeCategory.self]) {
            (bar: ShellTabBar, _) in bar.updateHeight()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Redraws the tab bar using the store's state
    func apply(_ state: TabularFeature.State, showsFilledSelection: Bool) {
        for item in tabItems {
            item.update(badge: state.badge(for: item.tab), showsFilledSelection: showsFilledSelection)
        }

        items = tabItems

        let selected = tabItems.first { $0.tab == state.tab }
        if selectedItem !== selected {
            selectedItem = selected
        }
    }

    /// Which tab a given item stands for.
    func tab(for item: UITabBarItem) -> TabularFeature.Tab? {
        (item as? ShellTabBarItem)?.tab
    }

    // MARK: Height

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Attachment is when the first honest measurement becomes possible: the initial one ran with no window, no
        // traits, and no safe area, and `sizeThatFits` answers for the state the bar is in when asked.
        updateHeight()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateHeight()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeight()

        let room = max(0, bounds.height - safeAreaInsets.bottom)
        if room != lastReportedRoom {
            lastReportedRoom = room
            onRoomChange?(room)
        }
    }

    /// Re-measures the bar and moves the height constraint to match, if it doesn't already.
    private func updateHeight() {
        let width = window?.bounds.width ?? superview?.bounds.width ?? bounds.width
        let fitting = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        // Half a point: below the finest pixel grid the bar can render on, so anything smaller is measurement
        // noise rather than a real height change worth a layout pass.
        guard fitting > 0, abs(heightConstraint.constant - fitting) > 0.5 else { return }
        heightConstraint.constant = fitting
    }

    private func applyAppearance() {
        let appearance = UITabBarAppearance()
        if #available(iOS 26.0, *) {
            // The system's floating material stands on its own, and the globe runs underneath it.
            appearance.configureWithDefaultBackground()
        } else {
            // Older bars blur whatever is behind them, which here is the map. Opaque instead, so the bar reads as the
            // shell's floor rather than as another piece of the globe.
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .backgroundColor()
            // The view's own layer carries the same color as a backstop, in case the appearance's background does not
            // paint for a bar mounted directly in the window.
            backgroundColor = .backgroundColor()
        }
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
    }
}
