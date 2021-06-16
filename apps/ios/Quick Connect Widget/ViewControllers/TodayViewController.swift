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

final class TodayViewController: UIViewController {
        
    @IBOutlet private weak var connectionIcon: UIImageView?
    @IBOutlet private weak var electronContainerView: UIView?
    @IBOutlet private weak var connectionLabel: UILabel!
    @IBOutlet private weak var countryLabel: UILabel!
    @IBOutlet private weak var ipLabel: UILabel!
    @IBOutlet private weak var electronContainer: ElectronViewContainer!
    @IBOutlet private weak var connectButton: ProtonButton!
    @IBOutlet private weak var buttonContainerView: UIView!

    private let widgetFactory = WidgetFactory()
    private let viewModel: TodayViewModel
    
    required init?(coder aDecoder: NSCoder) {
        viewModel = widgetFactory.makeTodayViewModel()
        super.init(coder: aDecoder)
        viewModel.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .protonWidgetBackground
        connectionIcon?.image = connectionIcon?.image?.withRenderingMode(.alwaysTemplate)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.update()
    }
    
    @IBAction private func didTapConnectButton(_ sender: Any) {
        viewModel.connect()
    }
    
    // MARK: - Util

    private func setConnectButtonTitle(_ title: String) {
        UIView.performWithoutAnimation {
            connectButton.setTitle(title, for: .normal)
            connectButton.layoutIfNeeded()
        }
    }
    
    private func reAdjustSize() {
        guard let buttonWidth = connectButton.titleLabel?.realSize.width,
            view.frame.width > 357 else { // to fit everything on small screen sizes
                electronContainerView?.isHidden = true
                return
        }
        // if the size of both components is too big for the screen, we hide the loader
        electronContainerView?.isHidden = buttonWidth + connectionLabel.realSize.width > view.frame.width - 140
    }
    
    private func updateUI(_ buttonTitle: String = "", buttonState: ProtonButton.CustomState = .primary,
                               ipAddress: String? = nil, country: String? = nil, buttonHidden: Bool = false,
                               connectionString: String = "", connectionLabelTint: UIColor = .protonGreen(),
                               iconTint: UIColor = .protonGreen(), animate: Bool = false) {
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

// MARK: - NCWidgetProviding

extension TodayViewController: NCWidgetProviding {
    func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Void) {
        viewModel.update()
        completionHandler(NCUpdateResult.newData)
    }
}

// MARK: - TodayViewModelDelegate

extension TodayViewController: TodayViewModelDelegate {
    func didChangeState(state: TodayViewModelState) {
        switch state {
        case .blank:
            updateUI(buttonHidden: true, iconTint: .protonGrey())
        case let .connected(server, entryCountry: entryCountry, country: country):
            let connectionString: String
            if let entryCountry = entryCountry {
                 connectionString = "\(LocalizedString.connected) \(LocalizedString.via) \(entryCountry)"
            } else {
                connectionString = LocalizedString.connected
            }

            updateUI(LocalizedString.disconnect, buttonState: .destructive, ipAddress: server, country: country, connectionString: connectionString)
        case .connecting:
            updateUI(LocalizedString.cancel, buttonState: .destructive, connectionString: LocalizedString.connectingDotDotDot, animate: true)
        case .disconnected:
            updateUI(LocalizedString.quickConnect, connectionString: LocalizedString.disconnected, connectionLabelTint: .protonUnavailableGrey(), iconTint: .protonUnavailableGrey())
        case .error:
            updateUI(LocalizedString.ok, connectionString: LocalizedString.connectionFailed, connectionLabelTint: .protonUnavailableGrey(), iconTint: .protonUnavailableGrey())
        case .noGateway:
            updateUI(LocalizedString.logIn, connectionString: LocalizedString.logInToUseWidget, connectionLabelTint: .protonWhite())
        case .unreachable:
            updateUI(buttonHidden: true, connectionString: LocalizedString.networkUnreachable, connectionLabelTint: .protonUnavailableGrey(), iconTint: .protonUnavailableGrey())
        }
    }

    func didRequestUrl(url: URL) {
        extensionContext?.open(url, completionHandler: nil)
    }
}
