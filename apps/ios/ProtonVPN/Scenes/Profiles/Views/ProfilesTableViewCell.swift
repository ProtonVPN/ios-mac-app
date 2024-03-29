//
//  ProfilesTableViewCell.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit
import LegacyCommon
import ProtonCoreUIFoundations

class ProfilesTableViewCell: UITableViewCell {

    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var labelsStackView: UIStackView!
    @IBOutlet weak var profileName: UILabel!
    @IBOutlet weak var connectionDescription: UILabel!
    @IBOutlet weak var overlayButton: UIButton!
    @IBOutlet weak var connectButton: UIButton!
    
    var viewModel: ProfileItemViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            switch viewModel.icon {
            case .image(let name):
                profileImage.image = name
            case .arrowsSwapRight:
                profileImage.image = IconProvider.arrowsSwapRight
            case .bolt:
                profileImage.image = IconProvider.bolt
            case .circle(let color):
                profileImage.backgroundColor = UIColor(rgbHex: color)
                profileImage.layer.cornerRadius = 10
                profileImage.layer.masksToBounds = true
            }
            
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            profileName.attributedText = viewModel.description  // e.g. Country >> Server
            connectionDescription.attributedText = viewModel.name
            
            [profileImage, labelsStackView].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }
            
            stateChanged()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .backgroundColor()
        tintColor = .normalTextColor()
        connectButton.backgroundColor = .weakInteractionColor()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            connectButton.setTitle(nil, for: .normal)
            connectButton.setImage(IconProvider.chevronRight, for: .normal)
            connectButton.imageView?.tintColor = .white
            connectButton.backgroundColor = .clear
            connectButton.isUserInteractionEnabled = false
            overlayButton.isUserInteractionEnabled = false
        } else {
            renderConnectButton()
            connectButton.isUserInteractionEnabled = true
            overlayButton.isUserInteractionEnabled = true
        }
    }
    
    @IBAction func connect(_ sender: Any) {
        viewModel?.connectAction()
    }
    
    private func stateChanged() {
        if !isEditing {
            renderConnectButton()
        }
    }
    
    private func renderConnectButton() {
        guard let viewModel = viewModel else {
            return
        }
        if let icon = viewModel.imageInPlaceOfConnectIcon {
            connectButton.setImage(icon, for: .normal)
            connectButton.backgroundColor = .clear
        } else {
            connectButton.setImage(viewModel.connectIcon, for: .normal)
            connectButton.imageEdgeInsets = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
            connectButton.setAttributedTitle(nil, for: .normal)
            connectButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            connectButton.layer.cornerRadius = 20
            connectButton.backgroundColor = viewModel.isConnected ? .brandColor() : .weakInteractionColor()
        }
    }
}
