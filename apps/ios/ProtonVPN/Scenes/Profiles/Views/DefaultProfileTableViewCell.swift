//
//  OneLineTableViewCell.swift
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

class DefaultProfileTableViewCell: UITableViewCell {

    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    
    var viewModel: DefaultProfileViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                label.text = viewModel.title
                label.alpha = viewModel.alphaOfMainElements
                leftImageView.alpha = viewModel.alphaOfMainElements
                leftImageView.image = viewModel.image
                stateChanged()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        leftImageView.tintColor = .white
        backgroundColor = .backgroundColor()
        connectButton.backgroundColor = .weakInteractionColor()
        connectButton.tintColor = .white
        label.textColor = .normalTextColor()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        selectionStyle = .none
    }
    
    @IBAction func connect(_ sender: Any) {
        viewModel?.connectAction()
    }
    
    private func stateChanged() {
        guard let viewModel = viewModel else {
            return
        }
        if let icon = viewModel.imageInPlaceOfConnectIcon {
            connectButton.setImage(icon, for: .normal)
            connectButton.backgroundColor = .clear
        } else {
            connectButton.setImage(viewModel.connectIcon, for: .normal)
            connectButton.backgroundColor = viewModel.isConnected ? .brandColor() : .weakInteractionColor()
        }

    }
    
}
