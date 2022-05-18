//
//  ConnectionBarViewController.swift
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
import ProtonCore_UIFoundations

class ConnectionBarViewController: UIViewController {
    
    @IBOutlet weak var notConnectedLabel: UILabel!
    @IBOutlet weak var connectedLabel: UILabel!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var arrowImage: UIImageView!
    
    var viewModel: ConnectionBarViewModel?
    var tap: UITapGestureRecognizer!
    var connectionStatusService: ConnectionStatusService!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.view.addGestureRecognizer(tap)
        
        view.backgroundColor = .secondaryBackgroundColor()
        connectedLabel.textColor = .normalTextColor()
        timerLabel.textColor = .normalTextColor()
        
        connectedLabel.text = LocalizedString.connected
        
        arrowImage.image = IconProvider.chevronRight.imageFlippedForRightToLeftLayoutDirection()
        arrowImage.tintColor = .iconWeak()

        viewModel?.onAppDisplayStateChanged = { [weak self] state in
            switch state {
            case .connecting:
                self?.setConnecting()
            case .connected:
                self?.setConnected()
            case .disconnecting, .disconnected:
                self?.setDisconnected()
            case .loadingConnectionInfo:
                self?.setLoadingConnectionInfo()
            }
        }
        viewModel?.updateConnected = { [weak self] in self?.updateConnected() }

        viewModel?.updateDisplayStateFromUIThread()
        viewModel?.updateStateFromUIThread()
    }
    
    func embed(in parentViewController: UIViewController, with containerView: UIView) {
        willMove(toParent: parentViewController)
        if let connectionBarView = view {
            containerView.addSubview(connectionBarView)
            connectionBarView.translatesAutoresizingMaskIntoConstraints = false
            connectionBarView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 1).isActive = true
            connectionBarView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1).isActive = true
        }
        parentViewController.addChild(self)
        didMove(toParent: parentViewController)
    }

    private func setLoadingConnectionInfo() {
        self.view.backgroundColor = .brandColor()
        self.connectedLabel.isHidden = true
        self.timerLabel.isHidden = true
        self.notConnectedLabel.isHidden = false
        self.notConnectedLabel.text = LocalizedString.loadingConnectionInfo
        self.notConnectedLabel.textColor = .normalTextColor()
        self.view.setNeedsDisplay()
    }
    
    private func setConnecting() {
        self.view.backgroundColor = .secondaryBackgroundColor()
        self.connectedLabel.isHidden = true
        self.timerLabel.isHidden = true
        self.notConnectedLabel.isHidden = false
        self.notConnectedLabel.text = LocalizedString.connectingDotDotDot
        self.notConnectedLabel.textColor = .notificationWarningColor()
        self.view.setNeedsDisplay()
    }
    
    private func setConnected() {
        self.view.backgroundColor = .brandColor()
        self.connectedLabel.isHidden = false
        self.timerLabel.isHidden = false
        self.notConnectedLabel.isHidden = true
        
        self.view.setNeedsDisplay()
        self.view.setNeedsLayout()
        
        updateConnected()
    }

    private func updateConnected() {
        timerLabel.text = viewModel?.timeString()
    }
    
    private func setDisconnected() {
        self.view.backgroundColor = .secondaryBackgroundColor()
        self.connectedLabel.isHidden = true
        self.timerLabel.isHidden = true
        self.notConnectedLabel.isHidden = false
        self.notConnectedLabel.text = LocalizedString.notConnected
        self.notConnectedLabel.textColor = .notificationErrorColor()
        self.arrowImage.isHidden = false
        
        self.view.setNeedsDisplay()
    }
    
    @objc private func handleTap() {
        connectionStatusService.presentStatusViewController()
    }
}
