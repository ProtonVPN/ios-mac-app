//
//  Created on 24/03/2022.
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

protocol ConnectTableViewCell {
    var mode: ConnectTableViewCellMode { get }
    var connectButton: UIButton! { get }
    var viewModel: ConnectViewModel? { get }
    func renderConnectButton()
}

extension ConnectTableViewCell {
    var mode: ConnectTableViewCellMode {
        if let text = viewModel?.textInPlaceOfConnectIcon {
            return .upgrade(text)
        } else if let icon = viewModel?.connectIcon {
            return .connect(icon)
        }
        return .upgrade("")
    }

    func renderConnectButton() {
        connectButton.backgroundColor = viewModel?.connectButtonColor
        connectButton.tintColor = viewModel?.textColor

        connectButton.setImage(mode.image, for: .normal)
        connectButton.setAttributedTitle(mode.title, for: .normal)
        connectButton.contentEdgeInsets = mode.contentEdgeInsets

        connectButton.setNeedsLayout()
    }
}

enum ConnectTableViewCellMode {
    case connect(UIImage)
    case upgrade(String)
}

extension ConnectTableViewCellMode {
    var cornerRadius: CGFloat {
        switch self {
        case .connect:
            return 20
        case .upgrade:
            return 8
        }
    }

    var contentEdgeInsets: UIEdgeInsets {
        switch self {
        case .connect:
            return UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        case .upgrade:
            return UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        }
    }

    var image: UIImage? {
        switch self {
        case .connect(let image):
            return image
        case .upgrade:
            return nil
        }
    }

    var title: NSAttributedString? {
        switch self {
        case .connect:
            return nil
        case .upgrade(let text):
            let attribbutes: [NSAttributedString.Key: UIFont] = [.font: .systemFont(ofSize: 13)]
            return NSAttributedString(string: text, attributes: attribbutes)
        }
    }
}
