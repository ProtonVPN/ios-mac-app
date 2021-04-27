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

protocol TodayViewControllerProtocol: AnyObject {
        
    func displayBlank()
    func displayUnreachable()
    func displayError()
    func displayConnected( _ server: String?, entryCountry: String?, country: String? )
    func displayDisconnected()
    func displayConnecting()
    func displayNoGateWay()
    
    func extensionOpenUrl( _ url: URL )
}

class TodayViewController: UIViewController, NCWidgetProviding, TodayViewControllerProtocol {
    
    var viewModel: TodayViewModel?
        
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
        var viewModel = WidgetFactory.shared.todayViewModel
        viewModel.viewController = self
        self.viewModel = viewModel
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .protonWidgetBackground
        connectionIcon?.image = connectionIcon?.image?.withRenderingMode(.alwaysTemplate)
        viewModel?.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.viewWillDisappear(animated)
    }
    
    func setConnectButtonTitle(_ title: String) {
        UIView.performWithoutAnimation {
            connectButton.setTitle(title, for: .normal)
            connectButton.layoutIfNeeded()
        }
    }
    
    @IBAction func didTapConnectButton(_ sender: Any) {
        viewModel?.connectAction(sender)
    }
    
    // MARK: - NCWidgetProviding
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        viewModel?.viewWillAppear(false)
        completionHandler(NCUpdateResult.newData)
    }
    
    // MARK: - TodayViewControllerProtocol
    
    func displayBlank() {
        genericStyle( buttonHidden: true, iconTint: .protonGrey())
    }
    
    func displayUnreachable() {
        genericStyle( buttonHidden: true, connectionString: LocalizedString.networkUnreachable,
                      connectionLabelTint: .protonUnavailableGrey(), iconTint: .protonUnavailableGrey())
    }
    
    func displayError() {
        genericStyle( LocalizedString.ok, connectionString: LocalizedString.connectionFailed,
                      connectionLabelTint: .protonUnavailableGrey(), iconTint: .protonUnavailableGrey() )
    }
        
    func displayNoGateWay(){
        genericStyle( LocalizedString.logIn, connectionString: LocalizedString.logInToUseWidget, connectionLabelTint: .protonWhite())
    }
    
    func displayConnected( _ server: String?, entryCountry:String?, country: String? ){
        var connectionString = LocalizedString.connected
        if let entryCountry = entryCountry {
             connectionString += " " + LocalizedString.via + " \(entryCountry)"
        }
        
        genericStyle( LocalizedString.disconnect,
                      buttonState: .destructive,
                      ipAddress: server,
                      country: country,
                      connectionString: connectionString )
    }
    
    func displayDisconnected(){
        genericStyle( LocalizedString.quickConnect, connectionString: LocalizedString.disconnected,
                      connectionLabelTint: .protonUnavailableGrey(), iconTint: .protonUnavailableGrey() )
    }
    
    func displayConnecting(){
        genericStyle( LocalizedString.cancel, buttonState: .destructive, connectionString: LocalizedString.connectingDotDotDot, animate: true )
    }
    
    func extensionOpenUrl(_ url: URL) {
        extensionContext?.open(url, completionHandler: nil)
    }
    
    // MARK: - Util
    
    private func reAdjustSize() {
        guard let buttonWidth = connectButton.titleLabel?.realSize.width,
            view.frame.width > 357 else { // to fit everything on small screen sizes
                electronContainerView?.isHidden = true
                return
        }
        // if the size of both components is too big for the screen, we hide the loader
        electronContainerView?.isHidden = buttonWidth + connectionLabel.realSize.width > view.frame.width - 140
    }
    
    private func genericStyle( _ buttonTitle: String = "", buttonState: ProtonButton.CustomState = .primary,
                               ipAddress: String? = nil, country: String? = nil, buttonHidden: Bool = false,
                               connectionString: String = "", connectionLabelTint: UIColor = .protonGreen(),
                               iconTint: UIColor = .protonGreen(), animate: Bool = false ) {
        ipLabel.isHidden = ipAddress == nil
        countryLabel.isHidden = country == nil
        buttonContainerView.isHidden = buttonHidden
        connectionIcon?.tintColor = iconTint
        setConnectButtonTitle(buttonTitle)
        countryLabel.attributedText = country?.attributed(withColor: .protonWhite(), fontSize: 14, lineSpacing: -2)
        ipLabel.attributedText = ipAddress?.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14)
        connectionLabel.attributedText = connectionString
            .attributed(withColor: connectionLabelTint, font: .systemFont(ofSize: 16, weight: .bold))
        
        if animate {
            electronContainer.animate()
        } else {
            electronContainer.stopAnimating()
        }
        
        reAdjustSize()
    }
}
