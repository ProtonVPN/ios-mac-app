//
//  AnnouncementFeatureView.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
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

import Foundation
import UIKit
import vpncore
import AlamofireImage

final class AnnouncementFeatureView: UIView {

    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!

    var model: OfferFeature? {
        didSet {
            titleLabel.text = model?.text

            if let iconUrl = model?.iconURL, let url = URL(string: iconUrl) {
                iconImageView.af.setImage(withURL: url, imageTransition: .crossDissolve(0.2))
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        AnnouncementFeatureView.nib.instantiate(withOwner: self, options: nil)
        contentView.frame = bounds
        addSubview(contentView)

        contentView.backgroundColor = .backgroundColor()
        titleLabel.textColor = .normalTextColor()
    }
}
