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
import SwiftUI
import UIKit

/// Keeps the presented tab sheet and `TabularFeature` agreeing about the detent, in both directions: the user dragging
/// the sheet reaches the store through the delegate, and a reducer decision (raising the sheet when a tab is chosen,
/// dropping it on connect) reaches the sheet through the observation below.
///
/// This is the only place that knows `UISheetPresentationController` exists. The identifiers stay private to the file,
/// so the feature above deals in its own `Detent` and nothing else.
@MainActor
final class ShellSheetController: NSObject {
    private let store: StoreOf<TabularFeature>
    /// Reports how much of the backdrop the sheet covers as it moves.
    private let overlap: SheetOverlap
    /// The presented sheet, so a navigation push can raise it in the same turn it reports its depth.
    private weak var sheet: UISheetPresentationController?
    /// The pages the sheet carries, for the floor treatment the sheet's own movement drives.
    private weak var pages: ShellPagesController?
    /// The bar the pages are chosen from, which the sheet's travel leaves alone but does redraw: its selected glyph
    /// loses its fill as the sheet comes to rest on its floor.
    private weak var bar: ShellTabBar?
    /// The active observation. Started once: presenting the pages again after another flow's root swap re-points the
    /// references above at the fresh presentation instead of observing twice over.
    private var observation: ObserveToken?

    init(store: StoreOf<TabularFeature>, overlap: SheetOverlap) {
        self.store = store
        self.overlap = overlap
    }

    /// Applies the store's current state to the sheet, the pages, and the bar: detent selection, shown page, and bar
    /// contents. The caller installs the full detent list at each presentation; a deep page swaps that list for the
    /// full detent alone through `applyPageDepth`.
    func observeShellState(sheet: UISheetPresentationController, pages: ShellPagesController, bar: ShellTabBar) {
        self.sheet = sheet
        self.pages = pages
        self.bar = bar
        guard observation == nil else {
            // A fresh presentation of the same pages: the observation only fires on store changes, so the store's
            // current state is applied to the new sheet by hand.
            applyShellState()
            return
        }
        observation = observe { [weak self] in
            self?.applyShellState()
        }
    }

    /// Brings the sheet and the pages to the store's current state. The equality checks each side makes are what
    /// prevent the delegates and the observation from chasing each other around a change either of them made.
    private func applyShellState() {
        let detent = store.detent

        // Depth changes normally arrive through the navigation delegate, which has already applied them by hand;
        // this catches any sender that only writes the state.
        applyPageDepth(store.isPageDeep)

        if let sheet, sheet.selectedDetentIdentifier != detent.identifier {
            sheet.animateChanges {
                sheet.selectedDetentIdentifier = detent.identifier
            }
        }

        // This is what answers the bar's taps: the bar only sends, and the page swap and the bar's own selection both
        // land when the store's change re-runs the observation.
        pages?.show(store.tab)
        applyBar()
    }

    /// The bar redrawn from its two inputs: the store, and how much of the sheet is showing above its floor. Called
    /// wherever either changes, and it writes every glyph each time rather than putting anything back.
    private func applyBar(floorPresence: CGFloat? = nil) {
        let presence = floorPresence ?? pages?.view.alpha ?? 1
        bar?.apply(store.state, showsFilledSelection: presence > 0)
    }

    /// Whether the sheet is currently restricted to the full detent for a deep page. Read from the sheet itself
    /// rather than stored here: a fresh presentation starts unrestricted, and stored state would miss that.
    private var isRestrictedToFull: Bool {
        sheet?.detents.map(\.identifier) == [TabularFeature.Detent.full.identifier]
    }

    /// Fades the pages out as the sheet nears the bar detent, where only the bar remains and the globe shows through
    /// to the bottom edge. During a drag the alpha is written directly every frame; on a settle it is animated. The
    /// view's current alpha is compared first, so a value already animating toward the target is not animated again
    /// (UIKit writes an animation's end value to the model up front).
    private func applyFloorPresence(sheetHeight: CGFloat, animated: Bool) {
        guard let pages else { return }
        // Detent heights are measured above the bottom safe area, but the reporter measures coverage of the whole
        // window, so the coverage the sheet holds at rest on the bar detent includes the home indicator inset. Without
        // adding it, the fade stops just short of finished and the home page stays faintly visible at the bar detent.
        let floor = TabularFeature.Detent.barHeight + (pages.view.window?.safeAreaInsets.bottom ?? 0)
        let span = max(Dimensions.floorFadeSpan, 1)
        let presence = min(max((sheetHeight - floor) / span, 0), 1)
        guard abs(presence - pages.view.alpha) > 0.01 else { return }
        // The bar is mounted in the window, not in an ancestor shared with these views, so this animation block
        // cannot pick up the bar's pending layout and animate the bar along with the fade.
        UIView.animate(withDuration: animated ? Self.settleDuration : 0) {
            pages.view.alpha = presence
        }
        // Not animatable, and it lays the bar out, so it stays out of the block above.
        applyBar(floorPresence: presence)
    }

    /// Restricts the sheet to the full detent while the visible tab is pushed beyond its root: the legacy detail
    /// pages are designed for the whole screen, so the lower detents have nothing to show. Popping back to the root
    /// restores the full detent list and the grabber.
    ///
    /// Called directly instead of waiting for the observation, which runs one turn later than a push can wait. When
    /// this raises the sheet, the completion fires after the animation lands, so a push can wait for the room to
    /// exist. Removing the restriction does not move the sheet; it only restores the detent list.
    private func applyPageDepth(_ isDeep: Bool, completion: (() -> Void)? = nil) {
        guard let sheet, isDeep != isRestrictedToFull else {
            completion?()
            return
        }
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

    /// Mirrors the sheet's movement onto the backdrop and the pages: directly while the sheet's geometry is current
    /// (the user holds it), and hands off the rest of the travel to a spring animation if the user does a flick.
    func trackSheetHeight(of presented: UIViewController) {
        let reporter = SheetHeightReporter()
        reporter.isUserInteractionEnabled = false
        reporter.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        reporter.frame = presented.view.bounds
        reporter.onReport = { [weak self] points, settling in
            guard let self else { return }
            let points = max(0, points)
            if settling {
                // The sheet has left for a destination on the render server's clock; ours animates to match.
                withAnimation(Self.settleSpring) { self.overlap.settle(toward: points) }
            } else {
                // Live geometry, so the backdrop and the fade track the finger with no animation of their own.
                overlap.report(points)
            }
            applyFloorPresence(sheetHeight: points, animated: settling)
        }
        presented.view.insertSubview(reporter, at: 0)
    }

    /// Approximates the sheet's own settle curve. The globe's centering and the pages' fade are both soft alignments,
    /// so a near match reads as one motion.
    private static let settleSpring = Animation.spring(response: 0.45, dampingFraction: 1)
    /// The same curve for UIKit, which takes a plain duration.
    private static let settleDuration: TimeInterval = 0.35
}

/// The sheet's fixed geometry: what the custom detents resolve with. The bar detent's height lives with the
/// `Detent` itself, where the bar's own rendering can read it too.
private enum Dimensions {
    /// The half rung's share of the available room, matching what the system's medium detent used to give.
    static let halfFraction: CGFloat = 0.5
    /// How far above the bar the pages have fully faded in. A little past the bar's own height, so the
    /// sheet reads as solid well before it is tall enough to show anything.
    static let floorFadeSpan: CGFloat = 120
}

/// Draws nothing and takes no touches, exists so that the sheet's movement can be observed for the backdrop.
private final class SheetHeightReporter: UIView {
    /// The sheet's coverage as layout sees it: current geometry from a drag frame, a rotation or a first layout, or
    /// the destination of a settle animation the sheet just left on.
    var onReport: ((_ points: CGFloat, _ settling: Bool) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let sheet = superview, let window else { return }
        // The sheet covers everything from its top edge down to the window's bottom edge.
        let overlap = window.bounds.height - sheet.convert(sheet.bounds, to: window).minY
        onReport?(overlap, hasGeometryAnimation(between: sheet, and: window))
        clearSheetBackground(between: sheet, and: window)
    }

    /// Whether any layer between the sheet and the window is animating. A drag produces a stream of layouts with
    /// current geometry and no animation; a settle produces one layout whose geometry is the destination, moved by
    /// an animation. UIKit decides which container it animates, so every ancestor is checked.
    private func hasGeometryAnimation(between sheet: UIView, and window: UIWindow) -> Bool {
        sequence(first: sheet) { $0 === window ? nil : $0.superview }
            .contains { !($0.layer.animationKeys()?.isEmpty ?? true) }
    }

    /// Clears the sheet's system-drawn backgrounds so the globe stays visible under a clear sheet.
    ///
    /// The system paints two of them: a background color on the drop-shadow container view, and, on iOS 26, a
    /// Liquid Glass platter layer mounted next to the presented view's layer subtree. Walking from the sheet's layer
    /// up to the window's layer, every background color found is cleared. Under any layer whose class is not plain
    /// `CALayer`, the sibling subtrees next to the sheet's own are hidden as well: that removes the platter but
    /// keeps the grabber, which sits inside the sheet's own subtree. The walk uses layers instead of views because
    /// the platter's parent is not any view's `layer`. It runs on every layout because the system paints these
    /// backgrounds again after appearance changes.
    private func clearSheetBackground(between sheet: UIView, and window: UIWindow) {
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

extension ShellSheetController: UISheetPresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheet: UISheetPresentationController) {
        let detent = TabularFeature.Detent(sheet.selectedDetentIdentifier)
        // A detent the store already holds is one we just applied, arriving back around.
        guard detent != store.detent else { return }
        store.send(.detentChanged(detent))
    }
}

extension ShellSheetController: UITabBarDelegate {
    func tabBar(_ bar: UITabBar, didSelect item: UITabBarItem) {
        guard let tab = (bar as? ShellTabBar)?.tab(for: item) else { return }
        let isReselect = tab == store.tab
        // Only the choice is reported. Which page comes forward, which glyph fills and whether the sheet has to rise
        // are all answered by the store's change coming back through the observation.
        store.send(.tabSelected(tab))
        // Choosing the tab already showing pops its stack to root, the escape a tab bar controller gives its navigation
        // tabs. The pop reports through the navigation delegate above, which restores the full detent list.
        if isReselect {
            pages?.navigation(of: tab)?.popToRootViewController(animated: true)
        }
    }
}

extension ShellSheetController: UINavigationControllerDelegate {
    /// Every tab's navigation controller reports here, which is how the shell learns whether the visible page is
    /// pushed beyond its root. A push has already raised the sheet through `makeRoom(for:thenPush:)`, so this
    /// matters mostly for pops: popping back to the root restores the full detent list. The sheet itself stays
    /// where it is until the user moves it.
    func navigationController(
        _ navigationController: UINavigationController,
        willShow _: UIViewController,
        animated _: Bool
    ) {
        guard let tab = pages?.tab(of: navigationController) else { return }
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
        case .bar: .custom(identifier: .bar) { _ in TabularFeature.Detent.barHeight }
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
