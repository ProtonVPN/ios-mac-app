//
//  CountryItemCellView.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa
import LegacyCommon
import Theme

final class BannerCellView: NSView {
    
    @IBOutlet private weak var leftImage: NSImageView!
    @IBOutlet private weak var rightShevron: NSImageView!
    @IBOutlet private weak var roundedBackgroundView: NSView!
    @IBOutlet private weak var label: NSTextField!
    @IBOutlet private weak var separatorViewTop: NSView!
    @IBOutlet private weak var separatorViewBottom: NSView!
    
    private var viewModel: BannerViewModel!

    override func awakeFromNib() {
        super.awakeFromNib()

        roundedBackgroundView.wantsLayer = true
        roundedBackgroundView.layer?.cornerRadius = 8
        roundedBackgroundView.layer?.backgroundColor = .cgColor(.background, [.strong])

        label.wantsLayer = true
        label.textColor = .color(.text, [.normal])

        rightShevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?.colored(.weak)

        [separatorViewTop, separatorViewBottom].forEach {
            $0.wantsLayer = true
            $0.layer?.backgroundColor = .cgColor(.border, .weak)
        }

        let trackingFrame = NSRect(origin: roundedBackgroundView.frame.origin, size: CGSize(width: roundedBackgroundView.frame.size.width, height: roundedBackgroundView.frame.size.height))
        let trackingArea = NSTrackingArea(rect: trackingFrame, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    func updateView(withModel viewModel: BannerViewModel) {
        self.viewModel = viewModel

        label.stringValue = viewModel.text
        leftImage.image = viewModel.leftIcon.image

        separatorViewTop.isHidden = !viewModel.separatorTop
        separatorViewBottom.isHidden = !viewModel.separatorBottom
    }

    // MARK: - Actions
    
    @IBAction private func didTap(_ sender: Any) {
        viewModel.action()
    }
    
    // MARK: - Accessibility

    override func accessibilityLabel() -> String? {
        viewModel.accessibilityLabel
    }

    override func accessibilityChildren() -> [Any]? {
        return []
    }

    // MARK: - Mouse hovering

    override func mouseEntered(with event: NSEvent) {
        addCursorRect(frame, cursor: .pointingHand)
    }

    override func mouseExited(with event: NSEvent) {
        removeCursorRect(frame, cursor: .pointingHand)
    }
}
