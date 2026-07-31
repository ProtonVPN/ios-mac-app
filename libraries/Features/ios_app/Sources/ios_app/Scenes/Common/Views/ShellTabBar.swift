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
/// It also means an animation over the sheet's contents is safe again: an animation block that touches a view inside
/// the sheet used to pick up the bar's pending layout through their shared ancestors.
final class ShellTabBar: UITabBar {
    /// Reports the room the bar wants above the safe area, so the pages behind it can keep their content clear of it.
    /// Called from layout, since that is when the answer can change.
    var onRoomChange: ((CGFloat) -> Void)?

    /// Whether the selected item shows its outline glyph like its neighbors. Set while the sheet rests on its floor,
    /// where the bar is the only chrome over the map and a filled glyph reads as loud.
    var showsOutlinedSelection = false {
        didSet {
            guard showsOutlinedSelection != oldValue else { return }
            applySelectionGlyphs()
        }
    }

    /// The filled selected-state images the items declared, kept aside while their outlines stand in, keyed per item so
    /// each goes back where it came from.
    private var filledSelectionImages: [ObjectIdentifier: UIImage?] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Mounts the bar along the window's bottom edge, over everything else the window shows.
    func mount(in window: UIWindow) {
        translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(self)
        // A presented sheet mounts in a container that is this view's sibling, so being added last is not enough to
        // stay in front of it.
        layer.zPosition = Dimensions.overlayDepth
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: window.leadingAnchor),
            trailingAnchor.constraint(equalTo: window.trailingAnchor),
            bottomAnchor.constraint(equalTo: window.bottomAnchor),
        ])
    }

    /// Moves the selection to `index` without telling the delegate, for a choice the store already made.
    func selectItem(at index: Int) {
        guard let item = items?[safe: index], item !== selectedItem else { return }
        selectedItem = item
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

    /// Swaps each item's selected-state image for its outline and back. Applied only when the treatment changes:
    /// writing to the items lays the bar out again, which is not free while the sheet is moving.
    private func applySelectionGlyphs() {
        items?.forEach { item in
            if showsOutlinedSelection {
                if filledSelectionImages[ObjectIdentifier(item)] == nil {
                    filledSelectionImages[ObjectIdentifier(item)] = item.selectedImage
                }
                item.selectedImage = item.image
            } else if let kept = filledSelectionImages.removeValue(forKey: ObjectIdentifier(item)) {
                item.selectedImage = kept
            }
        }
    }
}

/// The bar's fixed geometry.
private enum Dimensions {
    /// Far enough in front of the window's other children that the sheet's presentation container, which carries no
    /// depth of its own, cannot come between the bar and the user.
    static let overlayDepth: CGFloat = 1000
}
