//
//  TodayViewController.swift
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

import Reachability
import UIKit
import vpncore
import NotificationCenter

class TodayViewController: GenericViewController, NCWidgetProviding {
    
    @IBOutlet weak var connectionIcon: UIImageView?
    @IBOutlet weak var electronContainerView: UIView?
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var countryLabel: UILabel!
    @IBOutlet weak var ipLabel: UILabel!
    @IBOutlet weak var electronContainer: ElectronViewContainer!
    @IBOutlet weak var connectButton: ProtonButton!
    @IBOutlet weak var buttonContainerView: UIView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let viewModel = WidgetFactory.shared.todayViewModel
        viewModel.viewController = self
        self.viewModel = viewModel
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 30, green: 30, blue: 32)
        connectionIcon?.image = connectionIcon?.image?.withRenderingMode(.alwaysTemplate)
        connectionIcon?.tintColor = .protonGreen()
        electronContainer.animate()
    }
    
    override func viewWillLayoutSubviews() {
        if view.frame.width < 358 { // to fit everything on small screen sizes
            electronContainerView?.isHidden = true
        }
    }
    
    func setConnectButtonTitle(_ title: String) {
        UIView.performWithoutAnimation {
            connectButton.setTitle(title, for: .normal)
            connectButton.layoutIfNeeded()
        }
    }
    
    // MARK: - NCWidgetProviding
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        viewModel.viewWillAppear(false)
        completionHandler(NCUpdateResult.newData)
    }
    
    // MARK: - UI Functions
    
    func displayBlank() {
        connectionIcon?.tintColor = .protonGrey()
        electronContainer?.stopAnimating()
        connectionLabel.text = ""
        setConnectButtonTitle("")
        buttonContainerView.isHidden = true
        ipLabel.isHidden = true
        countryLabel.isHidden = true
    }
    
    func displayUnreachable() {
        buttonContainerView.isHidden = true
        ipLabel.isHidden = true
        countryLabel.isHidden = true
        connectionIcon?.tintColor = .protonUnavailableGrey()
        electronContainer?.stopAnimating()
        connectionLabel.attributedText = LocalizedString
            .networkUnreachable
            .attributed(withColor: .protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
    }
    
    func displayError() {
        ipLabel.isHidden = true
        countryLabel.isHidden = true
        connectionIcon?.tintColor = UIColor.protonUnavailableGrey()
        connectButton.customState = .primary
        setConnectButtonTitle(LocalizedString.ok)
        electronContainer?.stopAnimating()
        connectionLabel.attributedText = LocalizedString
            .connectionFailed
            .attributed(withColor: .protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
    }
        
    func displayNoGateWay(){
        electronContainer?.stopAnimating()
        countryLabel.isHidden = true
        ipLabel.isHidden = true
        connectButton.customState = .primary
        setConnectButtonTitle(LocalizedString.logIn)
        connectionIcon?.tintColor = .protonGreen()
        connectionLabel.attributedText = LocalizedString
            .logInToUseWidget
            .attributed(withColor: .protonWhite(), font: .systemFont(ofSize: 16, weight: .regular))
    }
    
    func displayConnected( _ server:String?, country:String? ){
        ipLabel.isHidden = server == nil
        countryLabel.isHidden = country == nil
        buttonContainerView.isHidden = false
        connectButton.customState = .destructive
        countryLabel.attributedText = country?.attributed(withColor: .protonWhite(), fontSize: 16)
        ipLabel.attributedText = server?.attributed(withColor: .protonWhite(), fontSize: 16)
        electronContainer?.stopAnimating()
        connectButton.setTitle(LocalizedString.disconnect, for: .normal)
        connectionIcon?.tintColor = .protonGreen()
        connectionLabel.attributedText = LocalizedString
            .connected
            .attributed(withColor: .protonGreen(), font: .boldSystemFont(ofSize: 16))
    }
    
    func displayDisconnected(){
        ipLabel.isHidden = true
        countryLabel.isHidden = true
        buttonContainerView.isHidden = false
        connectionIcon?.tintColor = UIColor.protonUnavailableGrey()
        connectButton.customState = .primary
        setConnectButtonTitle(LocalizedString.quickConnect)
        electronContainer?.stopAnimating()
        connectionLabel.attributedText = LocalizedString
            .disconnected
            .attributed(withColor: .protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
    }
    
    func displayConnecting(){
        ipLabel.isHidden = true
        countryLabel.isHidden = true
        buttonContainerView.isHidden = false
        setConnectButtonTitle(LocalizedString.cancel)
        electronContainer?.animate()
        connectionIcon?.tintColor = UIColor.protonGreen()
        connectButton.customState = .destructive
        connectionLabel.attributedText = LocalizedString
            .connectingDotDotDot
            .attributed(withColor: .protonGreen(), font: .systemFont(ofSize: 16, weight: .bold))
    }
}
