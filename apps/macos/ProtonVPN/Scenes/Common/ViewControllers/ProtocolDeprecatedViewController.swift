//
//  Created on 14/07/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Cocoa
import LegacyCommon

final class ProtocolDeprecatedViewController: WarningPopupViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        warningDescriptionLabel.isHidden = true
        warningScrollViewContainer.isHidden = false
        continueButton.title = viewModel.confirmTitle
        cancelButton.title = viewModel.cancelTitle
        setupLink()
    }

    private func setupLink() {
        warningDescription.hyperLink(originalText: viewModel.description, hyperLink: viewModel.linkDescription ?? "", urlString: viewModel.url ?? "")
    }

}

extension WarningPopupViewModel {
    convenience init(alert: ProtocolDeprecatedAlert) {
        self.init(
            title: alert.title!,
            description: alert.message!,
            linkDescription: alert.linkText,
            url: ProtocolDeprecatedAlert.kbURLString,
            onConfirm: alert.enableSmartProtocol,
            confirmTitle: alert.confirmTitle,
            onCancel: nil,
            cancelTitle: alert.dismissTitle
        )
    }
    
    convenience init(alert: IkeDeprecatedAlert) {
        self.init(
            title: alert.title!,
            description: alert.message!,
            linkDescription: alert.linkText,
            url: IkeDeprecatedAlert.kbURLString,
            onConfirm: alert.enableSmartProtocol,
            confirmTitle: alert.confirmTitle,
            onCancel: alert.dismiss,
            cancelTitle: alert.dismissTitle
        )
    }
}
