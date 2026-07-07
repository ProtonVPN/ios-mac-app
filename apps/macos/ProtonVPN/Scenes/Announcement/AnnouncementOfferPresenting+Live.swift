//
//  Created on 29/06/2026 by Max Kupetskyi.
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

import Announcement
import AppKit
import ComposableArchitecture
import Dependencies
import SwiftUI

/// Weakly tracks the presented controller so `\.dismiss` can close it without capturing a
/// non-Sendable view controller in the `@Sendable` presenter closures. Because the reference is
/// `weak`, an externally-closed window (Cmd+W / the native close button) auto-nils it and `dismiss`
/// becomes a safe no-op — no manual cleanup needed, and the controller is never retained here
private final class AnnouncementOfferControllerBox: @unchecked Sendable {
    weak var controller: NSViewController?
}

extension AnnouncementOfferPresenting: @retroactive DependencyKey {
    public static let liveValue: AnnouncementOfferPresenting = {
        let box = AnnouncementOfferControllerBox()
        return AnnouncementOfferPresenting(
            present: { store in
                MainActor.assumeIsolated {
                    @Dependency(\.windowService) var windowService
                    // Offer modals are shown one at a time. Dismiss any still-presented one before
                    // presenting the next, so it isn't left on screen
                    box.controller?.dismiss(nil)
                    let controller = NSHostingController(rootView: AnnouncementOfferView(store: store))
                    controller.title = "Proton VPN"
                    // The modal is a native window; size it to the content
                    controller.sizingOptions = []
                    controller.preferredContentSize = preferredOfferSize(for: store.panel)
                    box.controller = controller
                    windowService.presentKeyModal(viewController: controller, activatingApp: false)
                }
            },
            dismiss: {
                MainActor.assumeIsolated {
                    box.controller?.dismiss(nil)
                }
            }
        )
    }()
}

private let offerActionButtonArea: CGFloat = 76

/// Content size for the offer modal window. The image panel matches the offer image's aspect ratio;
/// the legacy panel uses a fixed portrait size (its content scrolls). Both are capped to the current
/// screen so the window always fits
private func preferredOfferSize(for panel: OfferPanel) -> CGSize {
    let maxSize = availableModalSize()
    switch panel.panelMode() {
    case let .image(imagePanel):
        return imageOfferSize(imagePanel, maxSize: maxSize)
    case .legacy, .none:
        return CGSize(width: min(420, maxSize.width), height: min(640, maxSize.height))
    }
}

/// The largest an offer modal should be on the current screen, leaving a margin
private func availableModalSize() -> CGSize {
    let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
    return CGSize(width: visible.width * 0.9, height: visible.height * 0.85)
}

private func imageOfferSize(_ panel: OfferPanel.ImagePanel, maxSize: CGSize) -> CGSize {
    // Source dimensions are pixel values of the (usually @2x) asset; convert to points.
    let pointScale = 1 / (NSScreen.main?.backingScaleFactor ?? 2)
    let maxImageHeight = max(maxSize.height - offerActionButtonArea, 0)

    // Desired image size in points; a square fallback when the source has no dimensions
    let desiredImage = if let source = panel.fullScreenImage.source.first,
                          let width = source.width, let height = source.height,
                          width > 0, height > 0 {
        CGSize(width: width * pointScale, height: height * pointScale)
    } else {
        CGSize(width: 480, height: 480)
    }

    // Scale down to fit the screen preserving aspect ratio
    let ratio = min(maxSize.width / desiredImage.width, maxImageHeight / desiredImage.height, 1)
    let image = CGSize(width: desiredImage.width * ratio, height: desiredImage.height * ratio)
    return CGSize(width: image.width, height: image.height + offerActionButtonArea)
}
