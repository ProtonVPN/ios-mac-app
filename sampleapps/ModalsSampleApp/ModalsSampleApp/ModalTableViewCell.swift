//
//  Created on 11/02/2022.
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

protocol PresentationModeSwitchDelegate: AnyObject {
    func didTapPresentationModeSwitch(style: UIModalPresentationStyle)
}

class ModalTableViewCell: UITableViewCell {
    @IBOutlet weak var modalTitle: UILabel!
}

class ModalPresentationTableViewCell: UITableViewCell {
    @IBOutlet weak var modalTitle: UILabel! {
        didSet {
            modalTitle.text = "Fullscreen presentation"
        }
    }
    @IBOutlet weak var switchButton: UISwitch! {
        didSet {
            switchButton.addTarget(self, action: #selector(didTapPresentationModeSwitch), for: .valueChanged)
        }
    }

    weak var delegate: PresentationModeSwitchDelegate?

    @objc func didTapPresentationModeSwitch() {
        let style: UIModalPresentationStyle = switchButton.isOn ? .fullScreen : .automatic
        delegate?.didTapPresentationModeSwitch(style: style)
    }
}
