//
//  Created on 28/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if os(macOS)
    import AppKit
    import SnapshotTesting
    import SwiftUI

    public extension SnapshotEnvironment {
        /// The size a macOS snapshot renders at.
        enum Layout: Sendable {
            /// Renders at exactly this size, for a view the app shows in a window or a popover whose size
            /// the design fixes.
            case fixed(CGSize)

            /// Renders at this width and whatever height the content asks for, for a view the app places in
            /// a column that sets only its width. The reference then follows the content instead of a height
            /// somebody measured once by hand.
            case fitting(width: CGFloat)
        }
    }

    public extension AssertSnapshot {
        /// Records or verifies a snapshot of a macOS view, hosted the way the application hosts it.
        ///
        /// Every macOS suite renders through this one function, so all of them pin the same three things:
        ///
        /// - The application's appearance, for the whole call. Theme reads `NSApp.effectiveAppearance` every
        ///   time it resolves a color, and SwiftUI takes `\.colorScheme` from the same place, so setting the
        ///   application covers both. A suite must not set `\.colorScheme` itself: that reaches SwiftUI's own
        ///   colors while leaving Theme's on whatever the machine is set to, and a light snapshot then comes
        ///   out with dark text.
        /// - A window. AppKit lays out and draws the rows of a `List` only after the view has one, and text
        ///   comes out with different antialiasing without one.
        /// - One pixel per point, so a reference recorded on a Retina display is the size the headless CI
        ///   machine renders.
        ///
        /// - Parameters:
        ///   - content: The view to render. It is built inside the appearance pin, because a view's
        ///     initializer can read a Theme color before anything draws.
        ///   - layout: The size to render at.
        ///   - appearance: Which appearance to render in. Pass a test argument when the screen is worth
        ///     recording light and dark.
        ///   - name: Tells apart snapshots that share a test name. Pass it when the test takes arguments,
        ///     because every argument reports the same name; leave it off otherwise and the reference image
        ///     is named after the test.
        @MainActor
        func assertSnapshot(
            of content: @autoclosure () -> some SwiftUI.View,
            layout: SnapshotEnvironment.Layout,
            appearance: SnapshotEnvironment.Appearance = .dark,
            named name: String? = nil,
            fileID: StaticString = #fileID,
            file filePath: StaticString = #filePath,
            testName: String = #function,
            line: UInt = #line,
            column: UInt = #column
        ) {
            SnapshotEnvironment.withAppearance(appearance) {
                SnapshotEnvironment.withHostedView(content(), layout: layout) { view in
                    assertSnapshot(
                        of: view,
                        as: .image(scale: 1),
                        named: name,
                        fileID: fileID,
                        file: filePath,
                        testName: testName,
                        line: line,
                        column: column
                    )
                }
            }
        }
    }

    private extension SnapshotEnvironment {
        /// A window that reports one pixel per point regardless of the screens the machine has.
        ///
        /// Pinning the bitmap's pixel dimensions is not enough for a stable snapshot: `NSHostingView` feeds
        /// the window's `backingScaleFactor` into SwiftUI as `\.displayScale`, and layout depends on it
        /// before anything draws — positions round to pixel boundaries at that scale, hairlines are
        /// `1/displayScale` points thick, and scale-variant assets are selected by it. A view laid out in a
        /// window on a Retina screen therefore renders different pixels into a 1x bitmap than the same view
        /// laid out on a 1x screen. Overriding the reported scale is the mechanism SnapshotTesting itself
        /// uses (its `ScaledWindow` pins 2x for `SCNView` snapshots), pointed at 1 instead.
        final class FixedScaleWindow: NSWindow {
            override var backingScaleFactor: CGFloat {
                1
            }
        }

        /// Hosts `content` in a window at the size `layout` asks for, lays it out, and calls `body` with the
        /// view to snapshot.
        ///
        /// The window stays alive for the whole of `body`, because AppKit lays out and draws the rows of a
        /// `List` only while the view showing them belongs to one. Nothing else holds the window, so an
        /// explicit lifetime keeps it from being released once the view has been handed over.
        @MainActor
        static func withHostedView<T>(
            _ content: some SwiftUI.View,
            layout: Layout,
            _ body: (NSView) -> T
        ) -> T {
            let size = switch layout {
            case let .fixed(size):
                size
            case let .fitting(width):
                CGSize(width: width, height: fittingHeight(of: content, width: width))
            }
            let controller = NSHostingController(rootView: content.frame(width: size.width, height: size.height))

            let window = FixedScaleWindow(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = controller
            window.setContentSize(size)
            window.layoutIfNeeded()
            controller.view.layoutSubtreeIfNeeded()

            return withExtendedLifetime(window) { body(controller.view) }
        }

        /// The height `content` needs when it is `width` wide.
        ///
        /// The measurement goes through a hosting view of that width, and reads the size AppKit says fits.
        /// `NSHostingController.sizeThatFits(in:)` is the obvious call and the wrong one: proposing no
        /// height reports the height of a single line of text that in fact wraps, and proposing an unbounded
        /// height reports infinity for any view that fills the space it is given.
        ///
        /// Measurement happens inside a `FixedScaleWindow` because a windowless hosting view measures under
        /// whatever `displayScale` the machine defaults to, and text that rounds to 33.5pt under one scale
        /// rounds to 34pt under another — shifting every row below it. The result is then rounded up to a
        /// whole point: at one pixel per point a fractional height would draw a partial last pixel row.
        @MainActor
        static func fittingHeight(of content: some SwiftUI.View, width: CGFloat) -> CGFloat {
            let controller = NSHostingController(rootView: content.frame(width: width))
            let window = FixedScaleWindow(
                contentRect: CGRect(origin: .zero, size: CGSize(width: width, height: 0)),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = controller
            controller.view.frame.size.width = width
            return withExtendedLifetime(window) {
                controller.view.fittingSize.height.rounded(.up)
            }
        }
    }
#endif
