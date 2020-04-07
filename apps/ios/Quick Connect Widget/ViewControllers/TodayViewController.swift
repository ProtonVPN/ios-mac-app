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
    }
    
    override func viewWillLayoutSubviews() {
        if view.frame.width < 358 { // to fit everything on small screen sizes
            electronContainerView?.isHidden = true
        }
    }

    // MARK: - NCWidgetProviding
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        print("------------------------------------------------------------")
        print("--------------------widgetPerformUpdate-----------------------")
        print("------------------------------------------------------------")
//        displayBlank()
        completionHandler(NCUpdateResult.newData)
    }
    
    // MARK: - UI Functions
    
    func displayBlank() {
        connectionIcon?.tintColor = .protonGrey()
        electronContainer?.stopAnimating()
        connectionLabel.text = ""
        setConnectButtonTitle("")
        buttonContainerView.isHidden = true
        connectButton.isHidden = true
    }
    
    func setConnectButtonTitle(_ title: String) {
        UIView.performWithoutAnimation {
            connectButton.setTitle(title, for: .normal)
            connectButton.layoutIfNeeded()
        }
    }
    
    func displayUnreachable() {
        connectionIcon?.tintColor = UIColor.protonUnavailableGrey()
        electronContainer?.stopAnimating()
        connectionLabel.attributedText = LocalizedString
            .networkUnreachable
            .attributed(withColor: .protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
        setConnectButtonTitle("")
        connectButton.isHidden = true
    }
    
    func displayError() {
        connectionIcon?.tintColor = UIColor.protonUnavailableGrey()
        connectionLabel.attributedText = LocalizedString
            .connectionFailed
            .attributed(withColor: .protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
        connectButton.customState = .primary
        setConnectButtonTitle(LocalizedString.ok)
        electronContainer?.stopAnimating()
    }
        
    func displayConnected( _ server:String?, country:String? ){
        ipLabel.isHidden = false
        countryLabel.isHidden = false
        countryLabel.attributedText = country?.attributed(withColor: .protonRed(), fontSize: 16)
        ipLabel.attributedText = server?.attributed(withColor: .protonRed(), fontSize: 16)
        connectButton.setTitle(LocalizedString.disconnect, for: .normal)
        electronContainer?.animate()
        connectionIcon?.tintColor = .protonGreen()
        connectionLabel.attributedText = LocalizedString
            .connected
            .attributed(withColor: .protonGreen(), font: .boldSystemFont(ofSize: 16))
    }
    
    func setConnectedLabel( _ connectedText: NSMutableAttributedString) {       
        let fullRange = (connectedText.string as NSString).range(of: connectedText.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 6
        
        let runningRange = (connectedText.string as NSString).range(of: LocalizedString.connected)
        let runningParagraphStyle = NSMutableParagraphStyle()
        runningParagraphStyle.alignment = .left
        runningParagraphStyle.lineSpacing = 4
        
        connectedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        connectedText.addAttribute(.paragraphStyle, value: runningParagraphStyle, range: runningRange)
        connectionLabel.attributedText = connectedText
    }
}
