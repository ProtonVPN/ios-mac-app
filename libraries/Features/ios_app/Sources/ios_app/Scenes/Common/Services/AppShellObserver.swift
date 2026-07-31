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
import SwiftUI
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
    /// Reports how much of the backdrop the sheet covers as it moves.
    private let overlap: SheetOverlap

    init(store: StoreOf<TabularFeature>, overlap: SheetOverlap) {
        self.store = store
        self.overlap = overlap
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

    /// Mirrors the sheet's movement onto the backdrop: directly while the sheet's geometry is current
    /// (the user holds it), and by this side's own spring once a release hands the rest of the travel to
    /// a render-server animation, whose frames exist out of process where no in-process sample can
    /// reliably land on the right one.
    func trackSheetHeight(of presented: UIViewController) {
        let reporter = SheetHeightReporter()
        reporter.isUserInteractionEnabled = false
        reporter.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        reporter.frame = presented.view.bounds
        reporter.onMove = { [weak self] overlap in
            self?.overlap.report(max(0, overlap))
        }
        reporter.onSettle = { [weak self] target in
            guard let self else { return }
            withAnimation(Self.settleSpring) { self.overlap.settle(toward: max(0, target)) }
        }
        presented.view.insertSubview(reporter, at: 0)
    }

    /// Approximates the sheet's own settle curve. The globe's centering is a soft alignment, so a near
    /// match reads as one motion; what matters is that this animation runs in-process, where it cannot
    /// land out of step with itself the way sampled render-server frames can.
    private static let settleSpring = Animation.spring(response: 0.45, dampingFraction: 1)
}

/// The sheet's fixed geometry: what the custom detents resolve with.
private enum Dimensions {
    /// The bar detent's height.
    static let barHeight: CGFloat = 100
    /// The half rung's share of the available room, matching what the system's medium detent used to give.
    static let halfFraction: CGFloat = 0.5
}

/// A zero-cost passenger in the sheet: it draws nothing and takes no touches, and exists only so that the sheet's
/// movement can be observed from inside it, through layout.
///
/// Layout is where the sheet's geometry is trustworthy. While the user holds the grabber, UIKit sets the sheet's frame
/// directly with the touch, so layout runs every frame with current geometry. When the user lets go, UIKit hands the
/// rest of the travel to a render-server animation: the model jumps straight to the destination, layout runs once, and
/// the frames in between exist only out of process. So the reporter reports what layout shows, and says which of the
/// two it is: geometry the sheet is at right now (`onMove`), or a destination it has just left for (`onSettle`), for
/// the owner to animate to on its own clock rather than chase.
private final class SheetHeightReporter: UIView {
    /// The sheet is at `overlap` right now: a drag frame, a rotation, or its first layout.
    var onMove: ((_ overlap: CGFloat) -> Void)?
    /// The sheet just left for `target` on a render-server animation.
    var onSettle: ((_ target: CGFloat) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let sheet = superview, let window else { return }
        // The sheet covers everything from its top edge down to the window's bottom edge.
        let overlap = window.bounds.height - sheet.convert(sheet.bounds, to: window).minY
        if hasGeometryAnimation(between: sheet, and: window) {
            onSettle?(overlap) // the model already holds the destination
        } else {
            onMove?(overlap)
        }
    }

    /// Whether any layer from the sheet up to the window is animating, which is what tells a settle's
    /// single destination layout apart from a drag's stream of direct ones. Checked over the whole
    /// ancestor chain because which container UIKit animates is its own business.
    private func hasGeometryAnimation(between sheet: UIView, and window: UIWindow) -> Bool {
        sequence(first: sheet) { $0 === window ? nil : $0.superview }
            .contains { !($0.layer.animationKeys()?.isEmpty ?? true) }
    }
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
