//
//  Created on 03/02/2022.
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

import UIKit
import Theme
import Theme_iOS

final class AccountDetailsTableViewCell: UITableViewCell {

    @IBOutlet private var initialsRect: UIView!
    @IBOutlet private var initialsText: UILabel!
    @IBOutlet private var username: UILabel!
    @IBOutlet private var plan: UILabel!

    var completionHandler: (() -> Void)?

    func select() {
        completionHandler?()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    func setupViews() {
        backgroundColor = .secondaryBackgroundColor()
        initialsRect.layer.cornerRadius = 8
        initialsRect.backgroundColor = .brandColor()
        initialsText.textColor = .color(.text, .primary)
        username.textColor = .color(.text)
        plan.textColor = .color(.text, .weak)
        accessibilityIdentifier = "Account Details cell"
    }

    func setup(initials: NSAttributedString,
               username: NSAttributedString,
               plan: NSAttributedString,
               handler: @escaping () -> Void) {
        self.initialsText.attributedText = initials
        self.username.attributedText = username
        self.plan.attributedText = plan
        self.completionHandler = handler
    }
}
