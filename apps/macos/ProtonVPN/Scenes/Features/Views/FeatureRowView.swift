//
//  FeatureRowView.swift
//  ProtonVPN - Created on 22.04.21.
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
import SDWebImage

class FeatureRowView: NSView {
    
    @IBOutlet private weak var iconIV: NSImageView!
    @IBOutlet private weak var titleLbl: NSTextField!
    @IBOutlet private weak var descriptionLbl: NSTextField!
    @IBOutlet private weak var learnMoreBtn: InteractiveActionButton!
    
    var viewModel: FeatureCellViewModel! {
        didSet {
            titleLbl.attributedStringValue = viewModel.title.styled(.normal, font: .themeFont(.small))
            switch viewModel.icon {
            case .url(let url):
                iconIV.sd_setImage(with: url)
            case .image(let image):
                iconIV.image = image
            }

            descriptionLbl.attributedStringValue = viewModel.description.styled([.weak], font: .themeFont(.small), alignment: .natural)
            guard let footer = viewModel.footer else {
                learnMoreBtn.removeFromSuperview()
                return
            }
            learnMoreBtn.attributedTitle = footer.styled([.interactive, .active])
        }
    }

    @IBAction private func didTapLearnMoreBtn(_ sender: Any) {
        guard let urlContact = viewModel.urlContact else { return }
        SafariService().open(url: urlContact)
    }
}
