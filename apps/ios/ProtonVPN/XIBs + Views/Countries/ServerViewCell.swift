//
//  ServerViewCell.swift
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

class ServerViewCell: UITableViewCell {

    @IBOutlet weak var serverNameLabel: UILabel!
    @IBOutlet weak var cityNameLabel: UILabel!
    @IBOutlet weak var loadLabel: UILabel!
    @IBOutlet weak var loadValueLabel: UILabel!
    @IBOutlet weak var connectionPropertiesLabel: UILabel!
    
    @IBOutlet weak var connectButton: UIButton!
    
    var viewModel: ServerItemViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            
            backgroundColor = viewModel.backgroundColor
            selectionStyle = .none
            
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            serverNameLabel.attributedText = viewModel.description
            cityNameLabel.attributedText = viewModel.city
            loadLabel.attributedText = viewModel.loadLabel
            loadValueLabel.attributedText = viewModel.loadValue
            connectionPropertiesLabel.attributedText = viewModel.connectionProperties
            [serverNameLabel, cityNameLabel, loadLabel, loadValueLabel, connectionPropertiesLabel].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.stateChanged()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func connect() {
        viewModel?.connectAction()
        stateChanged()
    }
    
    @IBAction func connectButtonTap(_ sender: Any) {
        connect()
    }
    
    private func stateChanged() {
        renderConnectButton()
    }
    
    private func renderConnectButton() {
        if let text = viewModel?.textInPlaceOfConnectIcon {
            connectButton.setImage(nil, for: .normal)
            connectButton.setTitle(text, for: .normal)
        } else {
            connectButton.setImage(viewModel?.connectIcon, for: .normal)
            connectButton.setTitle(nil, for: .normal)
        }
    }
}
