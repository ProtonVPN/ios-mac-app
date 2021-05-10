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
        
        view.backgroundColor = .protonBlack()
        connectedLabel.textColor = .protonWhite()
        timerLabel.textColor = .protonWhite()
        
        connectedLabel.text = LocalizedString.connected
        
        arrowImage.image = arrowImage.image?.imageFlippedForRightToLeftLayoutDirection()
        
        viewModel?.setConnecting = { [weak self] in self?.setConnecting() }
        viewModel?.setConnected = { [weak self] in self?.setConnected() }
        viewModel?.updateConnected = { [weak self] in self?.updateConnected() }
        viewModel?.setDisconnected = { [weak self] in self?.setDisconnected() }
        
        viewModel?.updateState()
    }
    
    func embed(in parentViewController: UIViewController, with containerView: UIView) {
        willMove(toParent: parentViewController)
        if let connectionBarView = view {
            containerView.addSubview(connectionBarView)
            connectionBarView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            connectionBarView.frame = containerView.bounds
        }
        parentViewController.addChild(self)
        didMove(toParent: parentViewController)
    }
    
    private func setConnecting() {
        self.view.backgroundColor = .protonBlack()
        self.connectedLabel.isHidden = true
        self.timerLabel.isHidden = true
        self.notConnectedLabel.isHidden = false
        self.notConnectedLabel.text = LocalizedString.connectingDotDotDot
        self.notConnectedLabel.textColor = .protonYellow()
        self.view.setNeedsDisplay()
    }
    
    private func setConnected() {
        self.view.backgroundColor = .protonGreen()
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
        self.view.backgroundColor = .protonBlack()
        self.connectedLabel.isHidden = true
        self.timerLabel.isHidden = true
        self.notConnectedLabel.isHidden = false
        self.notConnectedLabel.text = LocalizedString.notConnected
        self.notConnectedLabel.textColor = .protonRed()
        self.arrowImage.isHidden = false
        
        self.view.setNeedsDisplay()
    }
    
    @objc private func handleTap() {
        connectionStatusService.presentStatusViewController()
    }
}
