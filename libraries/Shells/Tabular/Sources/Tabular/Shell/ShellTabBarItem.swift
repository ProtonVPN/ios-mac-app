//
//  Created on 07/08/2026.
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

/// One tab's item in the shell's tab bar.
final class ShellTabBarItem: UITabBarItem {
    let tab: TabularFeature.Tab

    init(tab: TabularFeature.Tab) {
        self.tab = tab
        super.init()
        title = tab.title
        accessibilityIdentifier = tab.accessibilityIdentifier
        update(badge: nil, showsFilledSelection: true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A capture in progress swaps the settings glyphs for the dotted variants, which is why the badge is an input.
    func update(badge: TabularFeature.Badge?, showsFilledSelection: Bool) {
        let glyphs = tab.glyphs(badge: badge)
        image = glyphs.outline
        selectedImage = showsFilledSelection ? glyphs.filled : glyphs.outline
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

    /// The identifiers the UI tests address the tabs by
    var accessibilityIdentifier: String {
        switch self {
        case .home: "Home"
        case .countries: "Countries"
        case .profiles: "Profiles"
        case .settings: "Settings back btn"
        }
    }

    /// The tab's outline and filled glyphs.
    ///
    /// - Todo: plumb through filled variants of earth + window terminal
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

    private static func settingsGlyph(_ resource: ImageResource) -> UIImage {
        UIImage(resource: resource).withRenderingMode(.alwaysOriginal)
    }
}
