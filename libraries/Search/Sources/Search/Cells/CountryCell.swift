//
//  CountryCell.swift
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

public final class CountryCell: UITableViewCell {

    public static var identifier: String {
        return String(describing: self)
    }

    public static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    @IBOutlet private weak var flagIcon: UIImageView!
    @IBOutlet private weak var countryName: UILabel!
    
    @IBOutlet private weak var p2pIV: UIImageView!
    @IBOutlet private weak var smartIV: UIImageView!
    @IBOutlet private weak var torIV: UIImageView!
    
    @IBOutlet private weak var connectButton: UIButton!
    @IBOutlet private var rightMarginConstraint: NSLayoutConstraint!
    @IBOutlet private var rightNoMarginConstraint: NSLayoutConstraint!    
    
    public var viewModel: CountryCellViewModel? {
        didSet {
            guard let viewModel = viewModel else {
                return
            }

            viewModel.updateTier()
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            countryName.text = viewModel.description
            countryName.numberOfLines = 2
            countryName.lineBreakMode = .byTruncatingTail
            countryName.tintColor = viewModel.textColor
            
            torIV.isHidden = !viewModel.torAvailable
            smartIV.isHidden = !viewModel.isSmartAvailable
            p2pIV.isHidden = !viewModel.p2pAvailable
            
            backgroundColor = .clear
            flagIcon.image = viewModel.flag
            [flagIcon, countryName, torIV, p2pIV, smartIV].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }
            
            stateChanged()
        }
    }

    @IBAction private func connectTapped(_ sender: Any) {
        viewModel?.connectAction()
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    private func stateChanged() {
        renderConnectButton()
    }
    
    private func renderConnectButton() {
        connectButton.backgroundColor = viewModel?.connectButtonColor

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
