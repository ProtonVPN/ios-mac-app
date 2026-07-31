//
//  Created on 28/07/2026.
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
import Ergonomics
import Home
import Mobile
import UIKit

/// Keeps the presented tab sheet and `AppFeature` agreeing about the detent, in both directions: the user dragging the
/// sheet reaches the store through the delegate, and a reducer decision (raising the sheet when a tab is chosen,
/// dropping it on connect) reaches the sheet through the observation below.
///
/// This is the only place that knows `UISheetPresentationController` exists. The identifiers stay private to the file,
/// so the feature above deals in its own `Detent` and nothing else.
@MainActor
final class AppShellObserver: NSObject {
    private let store: StoreOf<TabularFeature>
    /// Guards the store-to-UIKit half against re-entering while UIKit is telling us about the same change.
    private var isApplyingStoreDetent = false

    init(store: StoreOf<TabularFeature>) {
        self.store = store
    }

    /// Applies reducer decisions to the sheet. The ladder itself is fixed and applied once at
    /// presentation; only the selection moves. The equality checks are what prevent the delegates and
    /// this observation from chasing each other around a change either side made.
    func observeShellState(sheet: UISheetPresentationController, tabs: UITabBarController) {
        observe { [weak self, weak sheet, weak tabs] in
            guard let self else { return }
            let detent = store.detent

            if let sheet, sheet.selectedDetentIdentifier != detent.identifier {
                isApplyingStoreDetent = true
                sheet.animateChanges {
                    sheet.selectedDetentIdentifier = detent.identifier
                }
                isApplyingStoreDetent = false
            }

            if let tabs, let index = TabularFeature.Tab.allCases.firstIndex(of: store.tab), tabs.selectedIndex != index {
                tabs.selectedIndex = index
            }
            // At the floor the sheet is only tall enough for the grabber and the tab bar, so the pages
            // step aside rather than bleeding out from under it. `viewIfLoaded` keeps unvisited tabs
            // unbuilt: a page first loads when its tab is selected, and selecting raises the sheet off
            // the floor, so a freshly loaded page never misses a hide it needed.
            tabs?.viewControllers?.forEach { $0.viewIfLoaded?.isHidden = detent == .bar }
        }
    }
}

/// The sheet's fixed geometry: what the custom detents resolve with.
private enum Dimensions {
    /// The bar detent's height.
    static let barHeight: CGFloat = 100
    /// The half rung's share of the available room, matching what the system's medium detent used to give.
    static let halfFraction: CGFloat = 0.5
}

extension AppShellObserver: UISheetPresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheet: UISheetPresentationController) {
        guard !isApplyingStoreDetent else { return }
        store.send(.detentChanged(.init(sheet.selectedDetentIdentifier)))
    }
}

extension AppShellObserver: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect _: UIViewController) {
        guard let tab = TabularFeature.Tab.allCases[safe: tabBarController.selectedIndex] else { return }
        store.send(.tabSelected(tab))
    }
}

// MARK: - The one place the two vocabularies meet

private extension UISheetPresentationController.Detent.Identifier {
    /// The minimized height: enough for the grabber, the tab bar, and the bottom safe area together.
    static let bar = Self("bar")
    /// Half the available room. Our own rather than the system's medium, so its height is knowable.
    static let half = Self("half")
}

extension TabularFeature.Detent {
    var sheetDetent: UISheetPresentationController.Detent {
        switch self {
        case .bar: .custom(identifier: .bar) { _ in Dimensions.barHeight }
        case .half: .custom(identifier: .half) { $0.maximumDetentValue * Dimensions.halfFraction }
        case .full: .large()
        }
    }

    var identifier: UISheetPresentationController.Detent.Identifier {
        switch self {
        case .bar: .bar
        case .half: .half
        case .full: .large
        }
    }

    init(_ identifier: UISheetPresentationController.Detent.Identifier?) {
        switch identifier {
        case .large: self = .full
        case .half: self = .half
        default: self = .bar
        }
    }
}
