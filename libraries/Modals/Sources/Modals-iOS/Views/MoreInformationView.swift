//
//  Created on 13/04/2022.
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

final class MoreInformationView: UIView {

    // MARK: Outlets

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var button: UIButton!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var linkImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!

    // MARK: Properties

    var feature: Feature? {
        didSet {
            iconImageView.image = feature?.image
            linkImageView.image = feature?.linkImage
            titleLabel.text = feature?.title()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.layer.cornerRadius = 12
        contentView.backgroundColor = colors.secondaryBackground
        button.setTitle("", for: .normal)
        footerStyle(titleLabel)
    }

    @IBAction func buttonTapped(_ sender: UIButton) {
        guard let url = URL(string: "https://protonvpn.com/blog/no-logs-audit/") else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
