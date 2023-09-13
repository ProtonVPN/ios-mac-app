//
//  Created on 11.01.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Modals
import Foundation
import UIKit
import Theme

final class FeatureView: UIView {

    // MARK: Outlets
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!

    // MARK: Properties

    var feature: Feature? {
        didSet {
            guard let feature else { return }
            var textColor = UIColor.color(.text)
            if feature == .moneyGuarantee {
                iconImageView.tintColor = UIColor.color(.icon, .success)
                textColor = UIColor.color(.text, .success)
            } else {
                iconImageView.tintColor = UIColor.color(.icon, .interactive)
            }
            iconImageView.image = feature.image

            titleLabel.attributedText = feature.title().attributedString(size: 15,
                                                                         color: textColor,
                                                                         boldStrings: feature.boldTitleElements())
        }
    }
}
