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
import vpncore

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
                profileImage.image = UIImage(named: name)
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
        backgroundColor = .protonGrey()
        tintColor = .protonWhite()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            connectButton.setTitle(nil, for: .normal)
            connectButton.setImage(UIImage(named: "arrow-right"), for: .normal)
            connectButton.imageEdgeInsets = UIEdgeInsets.init(top: 20, left: 35, bottom: 20, right: 13)
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
        if let text = viewModel?.textInPlaceOfConnectIcon {
            connectButton.setImage(nil, for: .normal)
            connectButton.setTitle(text, for: .normal)
        } else {
            connectButton.setImage(viewModel?.connectIcon, for: .normal)
            connectButton.imageEdgeInsets = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
            connectButton.setTitle(nil, for: .normal)
        }
    }
    
}
