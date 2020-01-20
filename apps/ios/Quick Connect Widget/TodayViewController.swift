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

import NotificationCenter
import Reachability
import UIKit
import vpncore

class TodayViewController: UIViewController, NCWidgetProviding {
    
    @IBOutlet weak var connectionIcon: UIImageView?
    @IBOutlet weak var smallScreenLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var largeScreenLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var electronContainer: ElectronViewContainer?
    @IBOutlet weak var connectionLabel: UILabel!
    @IBOutlet weak var invisibleConnectButton: UIButton!
    @IBOutlet weak var connectButton: ProtonButton!
    
    let reachability = Reachability()
    
    let appStateManager: AppStateManager
    var vpnGateway: VpnGatewayProtocol?
    
    var timer: Timer?
    
    var connectionFailed = false
    
    required init?(coder aDecoder: NSCoder) {
        appStateManager = WidgetFactory.shared.appStateManager
        vpnGateway = WidgetFactory.shared.vpnGateway
        
        super.init(coder: aDecoder)
        
        WidgetFactory.shared.alertService.delegate = self
    }
    
    deinit {
        reachability?.stopNotifier()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard vpnGateway != nil else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: VpnGateway.connectionChanged, object: nil)
        
        reachability?.whenReachable = { [weak self] _ in
            self?.connectionChanged()
        }
        reachability?.whenUnreachable = { [weak self] _ in
            self?.unreachable()
        }
        do {
            try reachability?.startNotifier()
        } catch {}
    }
    
    override func viewWillLayoutSubviews() {
        if view.frame.width < 358 { // to fit everything on small screen sizes
            largeScreenLeadingConstraint.isActive = false
            smallScreenLeadingConstraint.isActive = true
            connectionIcon?.isHidden = true
            connectionIcon = nil
            electronContainer?.isHidden = true
            electronContainer = nil
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // refresh data
        ProfileManager.shared.refreshProfiles()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        view.backgroundColor = UIColor(red: 30/255, green: 30/255, blue: 32/255, alpha: 1.0)
        if let connectionIcon = connectionIcon {
            connectionIcon.image = connectionIcon.image?.withRenderingMode(.alwaysTemplate)
        }
        connectButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        invisibleConnectButton.isHidden = false
        connectButton.isHidden = false
        
        guard vpnGateway != nil else {
            connectionIcon?.tintColor = UIColor.protonGreen()
            connectionLabel.attributedText = LocalizedString.logInToUseWidget.attributed(withColor: UIColor.protonWhite(), font: .systemFont(ofSize: 16, weight: .regular))
            connectButton.customState = .primary
            setConnectButtonTitle(LocalizedString.logIn)
            return
        }
        
        connectionChanged()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        makeViewBlank()
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {        
        makeViewBlank()
        completionHandler(NCUpdateResult.newData)
    }
    
    @IBAction func connectAction(_ sender: Any) {
        guard let vpnGateway = vpnGateway else {
            connectionFailed = false
            
            // not logged in so open the app
            extensionContext?.open(URL(string: "protonvpn://")!, completionHandler: nil)
            return
        }
        
        if connectionFailed {
            // error
            extensionContext?.open(URL(string: "protonvpn://")!, completionHandler: nil)
            return
        }
        
        switch vpnGateway.connection {
        case .connected:
            vpnGateway.disconnect()
        case .connecting:
            vpnGateway.stopConnecting(userInitiated: true)
        case .disconnected, .disconnecting:
            vpnGateway.quickConnect()
        }
    }
    
    @objc private func connectionChanged() {
        timer?.invalidate()
        timer = nil
        
        if let reachability = reachability, reachability.connection == .none {
            unreachable()
            return
        } else {
            connectButton.isHidden = false
        }
        
        guard let vpnGateway = vpnGateway else { return }
        
        switch vpnGateway.connection {
        case .connected:
            connectionFailed = false
            
            connectionIcon?.tintColor = UIColor.protonGreen()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.setConnectedLabel()
                }
            })
            setConnectedLabel()
            connectButton.customState = .destructive
            setConnectButtonTitle(LocalizedString.disconnect)
            electronContainer?.stopAnimating()
        case .connecting:
            connectionFailed = false
            
            connectionIcon?.tintColor = UIColor.protonGreen()
            connectionLabel.attributedText = LocalizedString.connectingDotDotDot.attributed(withColor: UIColor.protonGreen(), font: .systemFont(ofSize: 16, weight: .bold))
            connectButton.customState = .destructive
            setConnectButtonTitle(LocalizedString.cancel)
            electronContainer?.animate()
        case .disconnected, .disconnecting:
            if !connectionFailed {
                connectionIcon?.tintColor = UIColor.protonUnavailableGrey()
                connectionLabel.attributedText = LocalizedString.disconnected.attributed(withColor: UIColor.protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
                connectButton.customState = .primary
                setConnectButtonTitle(LocalizedString.quickConnect)
                electronContainer?.stopAnimating()
            }
        }
    }
    
    private func unreachable() {
        connectionIcon?.tintColor = UIColor.protonUnavailableGrey()
        electronContainer?.stopAnimating()
        connectionLabel.attributedText = LocalizedString.networkUnreachable.attributed(withColor: UIColor.protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
        setConnectButtonTitle("")
        connectButton.isHidden = true
    }
    
    private func setConnectedLabel() {
        let titleText = LocalizedString.connected.attributed(withColor: UIColor.protonGreen(), font: .boldSystemFont(ofSize: 16))
        let connectedText = NSMutableAttributedString(attributedString: titleText)
        
        if let server = appStateManager.activeServer {
            if server.isSecureCore {
                let secureCoreText = "\n\(server.exitCountryCode) \(LocalizedString.via) \(server.entryCountryCode)".attributed(withColor: .protonWhite(), fontSize: 12)
                connectedText.append(secureCoreText)
            } else if let countryString = LocalizationUtility.countryName(forCode: server.countryCode) {
                let countryText = "\n\(countryString)".attributed(withColor: .protonWhite(), fontSize: 12)
                connectedText.append(countryText)
            }
            if let ip = appStateManager.activeIp {
                let ipText = "\n\(String(format: LocalizedString.ipValue, ip))".attributed(withColor: .protonWhite(), fontSize: 12)
                connectedText.append(ipText)
            }
        }
        
        let fullRange = (connectedText.string as NSString).range(of: connectedText.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 6
        
        let runningRange = (connectedText.string as NSString).range(of: titleText.string)
        let runningParagraphStyle = NSMutableParagraphStyle()
        runningParagraphStyle.alignment = .left
        runningParagraphStyle.lineSpacing = 4
        
        connectedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        connectedText.addAttribute(.paragraphStyle, value: runningParagraphStyle, range: runningRange)
        connectionLabel.attributedText = connectedText
    }
    
    private func makeViewBlank() {
        timer?.invalidate()
        timer = nil
        
        connectionFailed = false
        
        connectionIcon?.tintColor = .protonGrey()
        electronContainer?.stopAnimating()
        connectionLabel.text = ""
        setConnectButtonTitle("")
        invisibleConnectButton.isHidden = true
        connectButton.isHidden = true
    }
    
    private func setConnectButtonTitle(_ title: String) {
        UIView.performWithoutAnimation {
            connectButton.setTitle(title, for: .normal)
            connectButton.layoutIfNeeded()
        }
    }
}

extension TodayViewController: ExtensionAlertServiceDelegate {
    
    func actionErrorReceived() {
        connectionFailed = true
        
        connectionIcon?.tintColor = UIColor.protonUnavailableGrey()
        connectionLabel.attributedText = LocalizedString.connectionFailed.attributed(withColor: UIColor.protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
        connectButton.customState = .primary
        setConnectButtonTitle(LocalizedString.ok)
        electronContainer?.stopAnimating()
    }
    
}
