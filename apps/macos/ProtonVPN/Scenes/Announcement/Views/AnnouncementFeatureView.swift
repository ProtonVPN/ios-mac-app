//
//  AnnouncementFeatureView.swift
//  ProtonVPN - Created on 2020-10-21.
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
import SDWebImage
import vpncore

final class AnnouncementFeatureView: NSView {
    @IBOutlet private weak var iconImageView: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private var contentView: NSView!

    let model: OfferFeature

    init(model: OfferFeature) {
        self.model = model
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        Bundle.main.loadNibNamed("AnnouncementFeatureView", owner: self, topLevelObjects: nil)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        contentView.pinTo(view: self)

        titleLabel.textColor = .protonWhite()
        titleLabel.stringValue = model.text

        if let url = URL(string: model.iconURL) {
            iconImageView.sd_setImage(with: url, completed: nil)
        }
    }
}
