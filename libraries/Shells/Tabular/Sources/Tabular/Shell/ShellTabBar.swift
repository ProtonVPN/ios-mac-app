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

import Strings
import Theme
import UIKit

/// The shell's tab bar, mounted in the window rather than in the sheet the pages ride in, since the tab bar behaves
/// strangely when flicking the detent sheet up + down otherwise.
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

    /// Redraws the bar from the store's state. Every drawn property is written on every call, so there is no
    /// previous value to put back.
    ///
    /// `showsFilledSelection` follows the sheet's height rather than the store: as the sheet settles on the bar
    /// detent, the selected glyph loses its filled variant, because the bar is then the only UI over the map and the
    /// filled glyph stands out too much there.
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
            // The view's own layer carries the same color as a backstop, in case the appearance's background does not
            // paint for a bar mounted directly in the window.
            backgroundColor = .backgroundColor()
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

    /// The tab's outline and filled glyphs. Only home and settings have distinct filled variants; countries and
    /// profiles show selection through tint alone. A capture in progress swaps the settings glyphs for the dotted
    /// variants, which is why the badge is an input here rather than something drawn on top of the glyph.
    func glyphs(badge: TabularFeature.Badge?) -> (outline: UIImage, filled: UIImage) {
        switch self {
        case .home:
            (Asset.Icons.house.image, Asset.Icons.houseFilled.image)
        case .countries:
            (Asset.Icons.earth.image, Asset.Icons.earth.image)
        case .profiles:
            (Asset.Icons.windowTerminal.image, Asset.Icons.windowTerminal.image)
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
