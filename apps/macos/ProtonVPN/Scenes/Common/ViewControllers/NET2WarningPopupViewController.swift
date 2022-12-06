//
//  Created on 2022-03-28.
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

import Cocoa
import vpncore

final class NET2WarningPopupViewController: WarningPopupViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        warningDescriptionLabel.isHidden = true
        warningScrollViewContainer.isHidden = false
        continueButton.title = viewModel.confirmTitle
        cancelButton.title = viewModel.cancelTitle
        cancelButton.style = .destructive
        setupLink()
    }

    private func setupLink() {
        warningDescription.hyperLink(originalText: viewModel.description, hyperLink: viewModel.linkDescription ?? "", urlString: viewModel.url ?? "")
    }
}

extension WarningPopupViewModel {
    convenience init(alert: NEKSOnT2Alert) {
        let image = AppTheme.Icon.switchOff.resizeWhilePreservingRatio(newWidth: 50)
        self.init(image: image,
                  title: alert.title!,
                  description: alert.message!,
                  linkDescription: alert.link,
                  url: NEKSOnT2Alert.t2kbUrlString,
                  onConfirm: alert.killSwitchOffAction.handler!,
                  confirmTitle: alert.killSwitchOffAction.title,
                  onCancel: alert.connectAnywayAction.handler!,
                  cancelTitle: alert.connectAnywayAction.title)
    }
}
