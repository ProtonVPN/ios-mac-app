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

/// Content size for the offer modal window. The image panel matches the offer image's aspect ratio
/// the legacy panel uses a fixed portrait size (its content scrolls)
private func preferredOfferSize(for panel: OfferPanel) -> CGSize {
    switch panel.panelMode() {
    case let .image(imagePanel):
        let actionButtonArea: CGFloat = 76
        return imageOfferSize(imagePanel, actionButtonArea: actionButtonArea)
    case .legacy, .none:
        return CGSize(width: 420, height: 640)
    }
}

private func imageOfferSize(_ panel: OfferPanel.ImagePanel, actionButtonArea: CGFloat) -> CGSize {
    // Source dimensions are pixel values of the (usually @2x) asset; convert to points.
    let pointScale = 1 / (NSScreen.main?.backingScaleFactor ?? 2)
    let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
    let maxImage = CGSize(width: visible.width * 0.9, height: visible.height * 0.85 - actionButtonArea)

    let fallback = CGSize(width: 480, height: 480 + actionButtonArea)
    guard let source = panel.fullScreenImage.source.first,
          let width = source.width, let height = source.height,
          width > 0, height > 0 else {
        return fallback
    }

    var image = CGSize(width: width * pointScale, height: height * pointScale)
    let ratio = min(maxImage.width / image.width, maxImage.height / image.height, 1)
    image = CGSize(width: image.width * ratio, height: image.height * ratio)
    return CGSize(width: image.width, height: image.height + actionButtonArea)
}
