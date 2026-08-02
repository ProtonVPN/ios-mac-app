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
    /// How much of the sheet is showing above its floor: 1 clear of it, 0 resting on it. Derived from the sheet's live
    /// height rather than the settled detent, so the pages fade with the drag rather than jumping between detents.
    private var floorPresence: CGFloat = 1
    /// Whether the sheet's ladder was last restricted to the full detent for a deep page. Only a real change may touch
    /// the sheet.
    private var detentsRestrictedToFull = false
    /// The presented sheet, so a navigation push can raise it in the same turn it reports its depth.
    private weak var sheet: UISheetPresentationController?
    /// The pages the sheet carries, for the floor treatment the sheet's own movement drives.
    private weak var pages: ShellPagesController?
    /// The bar the pages are chosen from, which the sheet's travel leaves alone.
    private weak var bar: ShellTabBar?
    /// The active observation. Started once: presenting the pages again after another flow's root swap re-points the
    /// references above at the fresh presentation instead of observing twice over.
    private var observation: ObserveToken?

    init(store: StoreOf<TabularFeature>, overlap: SheetOverlap) {
        self.store = store
        self.overlap = overlap
    }

    /// Applies reducer decisions to the sheet, the pages and the bar, starting with the state the store already holds.
    /// The full ladder is applied by the caller at each presentation; here the selection moves, and a deep page swaps
    /// the ladder for the full detent alone.
    func observeShellState(sheet: UISheetPresentationController, pages: ShellPagesController, bar: ShellTabBar) {
        self.sheet = sheet
        self.pages = pages
        self.bar = bar
        guard observation == nil else {
            // A fresh presentation of the same pages. The caller has just given the new sheet the full ladder, and
            // the observation only fires on store changes, so the restriction flag is trued up to the new sheet and
            // the store's current state is applied by hand.
            detentsRestrictedToFull = false
            applyShellState()
            return
        }
        observation = observe { [weak self] in
            self?.applyShellState()
        }
    }

    /// Brings the sheet, the pages and the bar to the store's current state. The equality checks each side makes are
    /// what prevent the delegates and the observation from chasing each other around a change either of them made.
    private func applyShellState() {
        let detent = store.detent

        // Depth changes normally arrive through the navigation delegate, which has already applied them by hand;
        // this catches any sender that only writes the state.
        applyPageDepth(store.isPageDeep)

        if let sheet, sheet.selectedDetentIdentifier != detent.identifier {
            isApplyingStoreDetent = true
            sheet.animateChanges {
                sheet.selectedDetentIdentifier = detent.identifier
            }
            isApplyingStoreDetent = false
        }

        if let index = TabularFeature.Tab.allCases.firstIndex(of: store.tab) {
            showPage(at: index)
        }
    }

    /// Brings a tab's page forward and moves the bar's selection with it. This both serves the bar's own taps, which
    /// need the page immediately, and the observation above, which is the backstop for any other sender.
    private func showPage(at index: Int) {
        pages?.show(pageAt: index)
        bar?.selectItem(at: index)
    }

    /// Fades the pages as the sheet approaches its floor, where the bar becomes the only view and the globe runs
    /// underneath it to the screen's bottom edge. Driven by the sheet's own height, so a drag carries the fade frame by
    /// frame; a release hands the rest to an animation of ours.
    private func applyFloorPresence(sheetHeight: CGFloat, animated: Bool) {
        guard let pages else { return }
        let span = max(Dimensions.floorFadeSpan, 1)
        let presence = min(max((sheetHeight - Dimensions.barHeight) / span, 0), 1)
        guard abs(presence - floorPresence) > 0.01 else { return }
        floorPresence = presence
        // An animation block here is safe now that the bar is mounted in the window: it used to reach the bar through
        // the ancestors it shared with these views and carry its pending layout along, which is what sent the bar
        // flying while the sheet was still on its way.
        UIView.animate(withDuration: animated ? Self.settleDuration : 0) {
            pages.view.alpha = presence
        }
        // Not animatable, and it lays the bar out, so it stays out of the block above.
        bar?.showsOutlinedSelection = presence == 0
    }

    /// Holds the sheet at full while the visible tab is pushed beyond its root: the legacy detail pages were designed
    /// for the whole screen, and there is nothing to read at half or on the floor. The ladder and the grabber return
    /// with the root.
    ///
    /// Applied by hand rather than left to the observation, which runs a turn later than the caller needs. Raising
    /// animates and reports when it has landed, so a push can wait for its room; the release on the way back only
    /// restores the ladder, since the sheet stays where it is.
    private func applyPageDepth(_ isDeep: Bool, completion: (() -> Void)? = nil) {
        guard let sheet, isDeep != detentsRestrictedToFull else {
            completion?()
            return
        }
        detentsRestrictedToFull = isDeep
        let apply = {
            sheet.detents = isDeep
                ? [TabularFeature.Detent.full.sheetDetent]
                : TabularFeature.Detent.allCases.map(\.sheetDetent)
            sheet.prefersGrabberVisible = !isDeep
            if isDeep {
                sheet.selectedDetentIdentifier = TabularFeature.Detent.full.identifier
            }
        }
        guard isDeep, sheet.selectedDetentIdentifier != TabularFeature.Detent.full.identifier else {
            apply()
            completion?()
            return
        }
        // The sheet's own animation carries the raise, and the transaction it runs in tells us when it has finished,
        // which is when the page waiting on the room may be pushed into it.
        CATransaction.begin()
        CATransaction.setCompletionBlock { completion?() }
        sheet.animateChanges(apply)
        CATransaction.commit()
    }

    /// Raises the sheet for a page about to be pushed onto `tab`'s stack and calls back once the room is there. A
    /// stack already at full needs none, so the push goes straight through.
    func makeRoom(for tab: TabularFeature.Tab, thenPush push: @escaping () -> Void) {
        store.send(.pageDepthChanged(tab: tab, isDeep: true))
        applyPageDepth(true, completion: push)
    }

    /// The tab a page stands for, by its position in the shell's tab order.
    private func tab(of page: UIViewController) -> TabularFeature.Tab? {
        guard let index = pages?.pages.firstIndex(of: page) else { return nil }
        return TabularFeature.Tab.allCases[safe: index]
    }

    /// Mirrors the sheet's movement onto the backdrop and the pages: directly while the sheet's geometry is current
    /// (the user holds it), and hands off the rest of the travel to a spring animation if the user does a flick.
    func trackSheetHeight(of presented: UIViewController) {
        let reporter = SheetHeightReporter()
        reporter.isUserInteractionEnabled = false
        reporter.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        reporter.frame = presented.view.bounds
        reporter.onMove = { [weak self] overlap in
            guard let self else { return }
            self.overlap.report(max(0, overlap))
            // Live geometry, so the fade tracks the finger with no animation of its own.
            applyFloorPresence(sheetHeight: max(0, overlap), animated: false)
        }
        reporter.onSettle = { [weak self] target in
            guard let self else { return }
            withAnimation(Self.settleSpring) { self.overlap.settle(toward: max(0, target)) }
            applyFloorPresence(sheetHeight: max(0, target), animated: true)
        }
        presented.view.insertSubview(reporter, at: 0)
    }

    /// Approximates the sheet's own settle curve. The globe's centering and the pages' fade are both soft alignments,
    /// so a near match reads as one motion.
    private static let settleSpring = Animation.spring(response: 0.45, dampingFraction: 1)
    /// The same curve for UIKit, which takes a plain duration.
    private static let settleDuration: TimeInterval = 0.35
}

/// The sheet's fixed geometry: what the custom detents resolve with.
private enum Dimensions {
    /// The bar detent's height.
    static let barHeight: CGFloat = 100
    /// The half rung's share of the available room, matching what the system's medium detent used to give.
    static let halfFraction: CGFloat = 0.5
    /// How far above the bar the pages have fully faded in. A little past the bar's own height, so the
    /// sheet reads as solid well before it is tall enough to show anything.
    static let floorFadeSpan: CGFloat = 120
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
        clearPresentation(between: sheet, and: window)
    }

    /// Whether any layer from the sheet up to the window is animating, which is what tells a settle's
    /// single destination layout apart from a drag's stream of direct ones. Checked over the whole
    /// ancestor chain because which container UIKit animates is its own business.
    private func hasGeometryAnimation(between sheet: UIView, and window: UIWindow) -> Bool {
        sequence(first: sheet) { $0 === window ? nil : $0.superview }
            .contains { !($0.layer.animationKeys()?.isEmpty ?? true) }
    }

    /// The system paints the sheet's chrome twice over: a solid backdrop on the drop-shadow container, and a Liquid
    /// Glass platter mounted as a sublayer branch beside the presented view's own. Either would end the backdrop's
    /// globe in an opaque strip however clear the presented view is. Both are recognized structurally, never by class
    /// name: everything between the sheet's layer and the window's is presentation chrome, so backgrounds found there
    /// are cleared, and where a chrome layer is a specialized compositor class, the sibling branches beside the sheet's
    /// own path are hidden (the platter mounts there; the grabber rides the sheet's branch and survives). The walk
    /// climbs layers rather than views because the platter's parent never appears as any view's `layer`. Re-applied
    /// every layout, since the system reasserts its paint across appearance changes.
    private func clearPresentation(between sheet: UIView, and window: UIWindow) {
        var pathChild: CALayer = sheet.layer
        while let parent = pathChild.superlayer, parent !== window.layer {
            if let view = parent.delegate as? UIView, view.backgroundColor != nil {
                view.backgroundColor = nil
            } else if parent.backgroundColor != nil {
                parent.backgroundColor = nil
            }
            if type(of: parent) != CALayer.self {
                for sibling in parent.sublayers ?? [] where sibling !== pathChild && !sibling.isHidden {
                    sibling.isHidden = true
                }
            }
            pathChild = parent
        }
    }
}

extension AppShellObserver: UISheetPresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheet: UISheetPresentationController) {
        guard !isApplyingStoreDetent else { return }
        store.send(.detentChanged(.init(sheet.selectedDetentIdentifier)))
    }
}

extension AppShellObserver: UITabBarDelegate {
    func tabBar(_ bar: UITabBar, didSelect item: UITabBarItem) {
        guard let index = bar.items?.firstIndex(of: item),
              let tab = TabularFeature.Tab.allCases[safe: index]
        else { return }
        // Brought forward by hand as well as sent, because the observation runs a turn later than a tap may be answered
        // in: a bar without a controller behind it shows nothing until someone acts.
        showPage(at: index)
        store.send(.tabSelected(tab))
        // Depth is the store's to answer, now that it keeps every tab's: switching to a tab left in a
        // detail page keeps the full sheet, and switching to one at its root releases it.
        applyPageDepth(store.isPageDeep)
    }
}

extension AppShellObserver: UINavigationControllerDelegate {
    /// Every UIKit tab's navigation controller reports here, so the shell knows when the visible page
    /// is pushed beyond its root.
    /// Pushes have already made their own room through `makeRoom(forPushThen:)`, so this is where a pop
    /// hands the ladder back. Nothing resizes on the way out: the sheet stays at full until the user
    /// moves it.
    func navigationController(
        _ navigationController: UINavigationController,
        willShow _: UIViewController,
        animated _: Bool
    ) {
        guard let tab = tab(of: navigationController) else { return }
        store.send(.pageDepthChanged(tab: tab, isDeep: navigationController.viewControllers.count > 1))
        // The store folds the report into the visible tab's answer, which is the one the sheet obeys: a
        // stack popped programmatically behind another tab moves nothing here.
        applyPageDepth(store.isPageDeep)
    }
}

// MARK: - The one place the two vocabularies meet

private extension UISheetPresentationController.Detent.Identifier {
    /// The minimized height: enough to leave the grabber just clear of the bar floating below it.
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
