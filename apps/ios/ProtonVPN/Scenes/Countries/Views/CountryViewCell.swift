//
//  CountryViewCell.swift
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

class CountryViewCell: UITableViewCell {

    @IBOutlet weak var flagIcon: UIImageView!
    @IBOutlet weak var countryName: UILabel!
    @IBOutlet weak var connectionProperties: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet var rightMarginConstraint: NSLayoutConstraint!
    @IBOutlet var rightNoMarginConstraint: NSLayoutConstraint!
    
    var section: Int = 0
    
    var viewModel: CountryItemViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            countryName.attributedText = viewModel.description
            countryName.numberOfLines = 2
            countryName.lineBreakMode = .byTruncatingTail
            
            connectionProperties.attributedText = viewModel.connectionProperties
            backgroundColor = viewModel.backgroundColor
            flagIcon.image = UIImage(named: viewModel.countryCode.lowercased() + "-plain")
            [flagIcon, countryName, connectionProperties].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }
            
            stateChanged()
        }
    }
    
    var servers: [ServerModel]?
    
    @IBAction func connectTapped(_ sender: Any) {
        viewModel?.connectAction()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    private func stateChanged() {
        renderConnectButton()
    }
    
    private func renderConnectButton() {
        if let text = viewModel?.textInPlaceOfConnectIcon {
            connectButton.setImage(nil, for: .normal)
            connectButton.setTitle(text, for: .normal)
            accessoryType = .none
            rightNoMarginConstraint.isActive = false
            rightMarginConstraint.isActive = true
        } else {
            connectButton.setImage(viewModel?.connectIcon, for: .normal)
            connectButton.setTitle(nil, for: .normal)
            accessoryType = .disclosureIndicator
            rightMarginConstraint.isActive = false
            rightNoMarginConstraint.isActive = true
        }
    }
}
