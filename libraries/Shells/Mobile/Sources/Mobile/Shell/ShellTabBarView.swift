//
//  Created on 01/08/2026.
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
import ProtonCoreUIFoundations
import Strings
import SwiftUI
import Theme

/// The shell's tab bar: a projection of the shell store, mounted in the window rather than in the sheet the pages
/// ride in.
///
/// The bar is the one piece of the shell that never moves, so it is kept where nothing can move it. Inside the sheet
/// it was laid out against a frame the sheet animates: fine under a drag, where UIKit sets that frame directly every
/// frame, but not on release, where the sheet's frame and the bar's offset within it settle on separate curves and the
/// composite throws the bar most of the way up the screen before easing it back. In the window there is only the one
/// constraint to the bottom edge, and it holds.
///
/// Everything drawn here is read from the store or the coverage channel: the selected tab, the sheet's coverage
/// (which decides whether the selection wears its filled glyph), and the settings tab's recording badge. Taps send
/// `tabSelected` and nothing else; the pages follow the store.
struct ShellTabBarView: View {
    /// The room the bar's content wants above the safe area: the inset a tab bar controller would have given the
    /// pages behind it.
    static let contentHeight: CGFloat = 49

    @Bindable var store: StoreOf<TabularFeature>
    /// How much of the backdrop the sheet covers, read live so the selection treatment follows the drag.
    let overlap: SheetOverlap

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabularFeature.Tab.allCases) { tab in
                ShellTabButton(
                    tab: tab,
                    isSelected: store.tab == tab,
                    // With the sheet on its floor the bar is the only thing over the map, where a filled glyph
                    // reads as loud, so the selection keeps its outline down there.
                    showsFilledSelection: overlap.points > TabularFeature.Detent.barHeight + 0.5,
                    badge: store.state.badge(for: tab),
                    action: { store.send(.tabSelected(tab)) }
                )
            }
        }
        .frame(height: Self.contentHeight)
        .frame(maxWidth: .infinity)
        .modifier(BarBackground())
        // The window mount pins this view to the bottom edge; rising with the keyboard would carry the bar over the
        // page that summoned it.
        .ignoresSafeArea(.keyboard)
    }
}

/// The bar's floor treatment: the system's floating glass where it exists, an opaque strip where it does not.
private struct BarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // The system's floating material stands on its own, and the globe runs underneath it.
            content
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal, Dimensions.floatingInset)
                .padding(.bottom, Dimensions.floatingLift)
        } else {
            // Older systems blur whatever is behind the bar, which here is the map. Opaque instead, so the bar reads
            // as the shell's floor rather than as another piece of the globe.
            content.background(Color(.background).ignoresSafeArea())
        }
    }
}

/// One tab's button: glyph over title, colored by selection, with the badge riding the glyph's corner.
private struct ShellTabButton: View {
    let tab: TabularFeature.Tab
    let isSelected: Bool
    /// Whether a selected glyph may show its filled variant.
    let showsFilledSelection: Bool
    let badge: TabularFeature.Badge?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Dimensions.glyphTitleGap) {
                tab.glyph(filled: isSelected && showsFilledSelection)
                    .overlay(alignment: .topTrailing) {
                        if badge == .recording {
                            Circle()
                                .fill(Color(.icon, .danger))
                                .frame(width: Dimensions.badgeDiameter, height: Dimensions.badgeDiameter)
                                .offset(x: Dimensions.badgeOverhang, y: -Dimensions.badgeOverhang)
                        }
                    }
                Text(tab.title)
                    .font(.system(size: Dimensions.titleSize, weight: .medium))
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(isSelected ? Color(.icon, [.interactive, .active]) : Color(.icon, .weak))
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }
}

private enum Dimensions {
    /// The gap between a tab's glyph and its title.
    static let glyphTitleGap: CGFloat = 2
    /// The title's point size, matching what the tab bar items drew.
    static let titleSize: CGFloat = 10
    /// The recording badge's diameter.
    static let badgeDiameter: CGFloat = 7
    /// How far the badge pokes past the glyph's corner.
    static let badgeOverhang: CGFloat = 2
    /// The floating bar's inset from the screen edges on systems that float it.
    static let floatingInset: CGFloat = 12
    /// How far the floating bar lifts off the safe area's floor.
    static let floatingLift: CGFloat = 4
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

    /// The identifiers the UI tests address the tabs by, kept word for word from the retired tab bar items.
    var accessibilityIdentifier: String {
        switch self {
        case .home: "Home"
        case .countries: "Countries"
        case .profiles: "Profiles"
        case .settings: "Settings back btn"
        }
    }

    /// The tab's glyph. Home and settings distinguish their selected state with a filled variant; countries and
    /// profiles read their selection from the tint alone, as they always have. The settings gear brings its own
    /// colors, so it renders as-is while the others take the button's.
    func glyph(filled: Bool) -> Image {
        switch self {
        case .home:
            Image(uiImage: filled ? IconProvider.houseFilled : IconProvider.house).renderingMode(.template)
        case .countries:
            Image(uiImage: IconProvider.earth).renderingMode(.template)
        case .profiles:
            Image(uiImage: IconProvider.windowTerminal).renderingMode(.template)
        case .settings:
            Image(filled ? .settingsTabbarActive : .settingsTabbar).renderingMode(.original)
        }
    }
}
