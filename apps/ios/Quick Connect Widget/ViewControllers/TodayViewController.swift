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
import ProtonCore_UIFoundations

final class TodayViewController: UIViewController {
    @IBOutlet private weak var connectionLabel: UILabel!
    @IBOutlet private weak var countryLabel: UILabel!
    @IBOutlet private weak var ipLabel: UILabel!
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
        view.backgroundColor = .backgroundColor()
        setupBackgroundColors()
    }

    private func setupBackgroundColors() {
        connectionLabel.backgroundColor = .clear
        countryLabel.backgroundColor = .clear
        ipLabel.backgroundColor = .clear
        buttonContainerView.backgroundColor = .clear
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
    
    private func updateUI(_ buttonTitle: String = "", buttonState: ProtonButton.CustomState = .primary,
                          ipAddress: String? = nil, country: String? = nil, buttonHidden: Bool = false,
                          connectionString: String = "", connectionLabelTint: UIColor = .normalTextColor(),
                          iconTint: UIColor = .brandColor(), animate: Bool = false) {
        ipLabel.isHidden = ipAddress == nil
        countryLabel.isHidden = country == nil
        buttonContainerView.isHidden = buttonHidden
        setConnectButtonTitle(buttonTitle)
        countryLabel.attributedText = country?.attributed(withColor: .normalTextColor(), fontSize: 14, alignment: .center, lineSpacing: -2)
        ipLabel.attributedText = ipAddress?.attributed(withColor: .weakTextColor(), fontSize: 14, alignment: .center)
        connectionLabel.attributedText = connectionString
            .attributed(withColor: connectionLabelTint, font: .systemFont(ofSize: 16, weight: .bold), alignment: .center)
    }
}

// MARK: - NCWidgetProviding

extension TodayViewController: NCWidgetProviding {
    func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Void) {
        viewModel.update {
            completionHandler(NCUpdateResult.newData)
        }
    }
}

// MARK: - TodayViewModelDelegate

extension TodayViewController: TodayViewModelDelegate {
    func didChangeState(state: TodayViewModelState) {
        connectButton.customState = .secondary

        switch state {
        case .blank:
            updateUI(buttonHidden: true, iconTint: .backgroundColor())
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
            connectButton.customState = .primary
            updateUI(LocalizedString.quickConnect, connectionString: LocalizedString.notConnected, connectionLabelTint: .notificationErrorColor(), iconTint: .weakTextColor())
        case .error:
            connectButton.customState = .secondary
            updateUI(LocalizedString.ok, connectionString: LocalizedString.connectionFailed, connectionLabelTint: .weakTextColor(), iconTint: .weakTextColor())
        case .noGateway:
            updateUI(LocalizedString.logIn, connectionString: LocalizedString.logInToUseWidget, connectionLabelTint: .normalTextColor())
        case .unreachable:
            updateUI(buttonHidden: true, connectionString: LocalizedString.networkUnreachable, connectionLabelTint: .weakTextColor(), iconTint: .weakTextColor())
        }
    }

    func didRequestUrl(url: URL) {
        extensionContext?.open(url, completionHandler: nil)
    }
}
