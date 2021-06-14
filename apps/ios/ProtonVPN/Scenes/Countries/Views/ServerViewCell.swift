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

final class ServerViewCell: UITableViewCell {

    @IBOutlet private weak var serverNameLabel: UILabel!
    @IBOutlet private weak var cityNameLabel: UILabel!
    @IBOutlet private weak var loadLbl: UILabel!
    @IBOutlet private weak var loadColorView: UIView!
    @IBOutlet private weak var loadContainingView: UIView!

    @IBOutlet private weak var smartIV: UIImageView!
    @IBOutlet private weak var torIV: UIImageView!
    @IBOutlet private weak var p2pIV: UIImageView!
    @IBOutlet private weak var streamingIV: UIImageView!

    @IBOutlet private weak var secureView: UIView!
    @IBOutlet private weak var secureCountryLbl: UILabel!
    @IBOutlet private weak var secureCoreIV: UIImageView!
    @IBOutlet private weak var connectButton: UIButton!
    
    var viewModel: ServerItemViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            
            backgroundColor = viewModel.backgroundColor
            selectionStyle = .none
            
            viewModel.connectionChanged = { [weak self] in self?.stateChanged() }
            serverNameLabel.text = viewModel.description
            serverNameLabel.isHidden = viewModel.viaCountry != nil
            cityNameLabel.text = viewModel.city
            cityNameLabel.isHidden = viewModel.viaCountry != nil
            secureView.isHidden = viewModel.viaCountry == nil
            
            smartIV.isHidden = !viewModel.smartAvailable
            torIV.isHidden = !viewModel.torAvailable
            p2pIV.isHidden = !viewModel.p2pAvailable
            streamingIV.isHidden = !viewModel.streamingAvailable
            loadContainingView.isHidden = viewModel.underMaintenance || viewModel.isUsersTierTooLow
            
            loadLbl.text = viewModel.loadValue
            loadColorView.backgroundColor = viewModel.loadColor
            [serverNameLabel, cityNameLabel, torIV, p2pIV, smartIV, streamingIV, secureView].forEach { view in
                view?.alpha = viewModel.alphaOfMainElements
            }
            
            if let viaCountry = viewModel.viaCountry {
                setupSecureCore(country: viaCountry.name, countryCode: viaCountry.code)
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.stateChanged()
            }
        }
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
        let isConnected = viewModel?.connectedUiState ?? false
        let maintenance = viewModel?.underMaintenance ?? false
        connectButton.backgroundColor = isConnected ? .protonGreen() : (maintenance ? .protonDarkGrey() :  .protonLightGrey())
        
        if let text = viewModel?.textInPlaceOfConnectIcon {
            connectButton.setImage(nil, for: .normal)
            connectButton.setTitle(text, for: .normal)
        } else {
            connectButton.setImage(viewModel?.connectIcon, for: .normal)
            connectButton.setTitle(nil, for: .normal)
        }
    }
    
    private func setupSecureCore( country: String, countryCode: String ) {
        secureCountryLbl.text = LocalizedString.via + " " + country.uppercased()
        secureCoreIV.image = UIImage(named: countryCode.lowercased() + "-plain")
    }
}
