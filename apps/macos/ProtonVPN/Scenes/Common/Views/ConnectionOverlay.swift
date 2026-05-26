//
//  ConnectionOverlay.swift
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

class ConnectionOverlay: NSView {
    private let blurRadius = 4.0

    override var isHidden: Bool {
        didSet {
            setup()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    private func setup() {
        let blurLayer = CALayer()
        wantsLayer = true
        layer = blurLayer

        if isHidden {
            layer?.needsDisplayOnBoundsChange = false
            return
        }

        layer?.masksToBounds = true
        layer?.needsDisplayOnBoundsChange = true

        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setDefaults()
        blurFilter.setValue(NSNumber(value: blurRadius), forKey: "inputRadius")
        layer?.backgroundFilters = [blurFilter]

        layer?.setNeedsDisplay()
    }
}
