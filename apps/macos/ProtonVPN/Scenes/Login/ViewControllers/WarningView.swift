//
//  Created on 03/05/2022.
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

import Foundation
import AppKit
import LegacyCommon
import Theme
import Strings

protocol WarningViewDelegate: class {
    func keychainHelpAction()
}

class WarningView: NSStackView {

    @IBOutlet private weak var warningLabel: PVPNTextField!
    @IBOutlet private weak var warningIcon: NSImageView!
    @IBOutlet private weak var helpLink: InteractiveActionButton!

    weak var helpDelegate: WarningViewDelegate?

    var showSupport: Bool = false {
        didSet {
            helpLink.isHidden = !showSupport
        }
    }

    var message: String? {
        didSet {
            guard let message = message else {
                isHidden = true
                return
            }
            isHidden = false
            warningLabel.attributedStringValue = message.styled(.danger, font: .themeFont(.small), alignment: .natural)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        isHidden = true

        helpLink.title = Localizable.learnMore
        helpLink.isHidden = true
        helpLink.target = self
        helpLink.action = #selector(keychainHelpAction)

        warningIcon.image = AppTheme.Icon.exclamationCircleFilled
        warningIcon.contentTintColor = .color(.icon, .danger)
    }

    @objc private func keychainHelpAction() {
        helpDelegate?.keychainHelpAction()
    }

}
