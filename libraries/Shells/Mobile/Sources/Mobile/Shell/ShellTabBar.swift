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

import ProtonCoreUIFoundations
import Strings
import Theme
import UIKit

/// The shell's tab bar, mounted in the window rather than in the sheet the pages ride in.
///
/// The bar is the one piece of the shell that never moves, so it is kept where nothing can move it. Inside the sheet it
/// was laid out against a frame the sheet animates: fine under a drag, where UIKit sets that frame directly every
/// frame, but not on release, where the sheet's frame and the bar's offset within it settle on separate curves and the
/// composite throws the bar most of the way up the screen before easing it back. In the window there is only the one
/// constraint to the bottom edge, and it holds.
///
/// It stays a `UITabBar` so the system draws it: on iOS 26 the default background is the floating glass bar, with the
/// system's own geometry, selection treatment and tab-bar accessibility semantics. What the shell owns is the content,
/// and `apply(_:showsFilledSelection:)` writes all of it on every pass, so the bar keeps no state of its own that
/// would need putting back.
final class ShellTabBar: UITabBar {
    /// Reports the room the bar wants above the safe area, so the pages behind it can keep their content clear of it.
    /// Called from layout, since the system decides this bar's height and only layout knows what it settled on.
    var onRoomChange: ((CGFloat) -> Void)?

    /// One item per tab, created once and never replaced: the bar holds these objects, so what changes is their
    /// contents.
    private let itemsByTab: [TabularFeature.Tab: UITabBarItem] = .init(
        uniqueKeysWithValues: TabularFeature.Tab.allCases.map { tab in
            let item = UITabBarItem(title: tab.title, image: nil, selectedImage: nil)
            item.accessibilityIdentifier = tab.accessibilityIdentifier
            return (tab, item)
        }
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyAppearance()
        items = TabularFeature.Tab.allCases.compactMap { itemsByTab[$0] }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The bar brought to the store's state. Every drawn property is written from `state` here, so there is never a
    /// previous value to restore: the glyphs are chosen rather than swapped and put back.
    ///
    /// `showsFilledSelection` is the sheet's business rather than the store's. It follows the sheet's current height,
    /// so the selected glyph loses its fill as the sheet comes to rest on its floor, where the bar is the only view
    /// over the map and a filled glyph reads as loud.
    func apply(_ state: TabularFeature.State, showsFilledSelection: Bool) {
        for (tab, item) in itemsByTab {
            let glyphs = tab.glyphs(badge: state.badge(for: tab))
            item.image = glyphs.outline
            item.selectedImage = showsFilledSelection ? glyphs.filled : glyphs.outline
        }
        let selected = itemsByTab[state.tab]
        if selectedItem !== selected {
            selectedItem = selected
        }
    }

    /// The tab an item stands for, so a tap can be reported as the tab the user chose rather than as a position.
    func tab(for item: UITabBarItem) -> TabularFeature.Tab? {
        itemsByTab.first { $0.value === item }?.key
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onRoomChange?(max(0, bounds.height - safeAreaInsets.bottom))
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
        }
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
    }
}

private extension TabularFeature.Tab {
    var title: String {
        switch self {
        case .home: Localizable.homeTab
        case .countries: Localizable.countries
        case .profiles: Localizable.profiles
        case .settings: Localizable.settings
        }
    }

    /// The identifiers the UI tests address the tabs by, kept word for word from the items the pages used to declare.
    var accessibilityIdentifier: String {
        switch self {
        case .home: "Home"
        case .countries: "Countries"
        case .profiles: "Profiles"
        case .settings: "Settings back btn"
        }
    }

    /// The tab's outline and filled glyphs. Only home and settings distinguish a filled state; countries and profiles
    /// read their selection from the tint alone, as they always have. A capture in progress swaps the settings gear
    /// for the pair wearing the dot, which is why the badge is an input here rather than something drawn on top.
    func glyphs(badge: TabularFeature.Badge?) -> (outline: UIImage, filled: UIImage) {
        switch self {
        case .home:
            (IconProvider.house, IconProvider.houseFilled)
        case .countries:
            (IconProvider.earth, IconProvider.earth)
        case .profiles:
            (IconProvider.windowTerminal, IconProvider.windowTerminal)
        case .settings:
            badge == .recording
                ? (Self.settingsGlyph(.settingsTabbarDot), Self.settingsGlyph(.settingsTabbarDotActive))
                : (Self.settingsGlyph(.settingsTabbar), Self.settingsGlyph(.settingsTabbarActive))
        }
    }

    /// Settings brings its own colored glyphs, so they are passed through untinted.
    private static func settingsGlyph(_ resource: ImageResource) -> UIImage {
        UIImage(resource: resource).withRenderingMode(.alwaysOriginal)
    }
}
