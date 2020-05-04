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
import vpncore

class DefaultProfileTableViewCell: UITableViewCell {

    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    
    var viewModel: DefaultProfileViewModel? {
        didSet {
            viewModel?.connectionChanged = { [weak self] in self?.stateChanged() }
            DispatchQueue.main.async { [weak self] in
                self?.label.text = self?.viewModel?.title
                self?.leftImageView.image = self?.viewModel?.image
                self?.stateChanged()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .protonGrey()
        label.textColor = .protonWhite()    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        selectionStyle = .none
    }
    
    @IBAction func connect(_ sender: Any) {
        viewModel?.connectAction()
    }
    
    private func stateChanged() {
        connectButton.setImage(viewModel?.connectIcon, for: .normal)
    }
    
}
