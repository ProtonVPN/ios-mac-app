//
//  TodayViewModel.swift
//  ProtonVPN - Created on 07/04/2020.
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
import vpncore
import NotificationCenter

class TodayViewModel: GenericViewModelImplementation<TodayViewController> {
    
    private let reachability = Reachability()
    private let appStateManager: AppStateManager!
    private var vpnGateway: VpnGatewayProtocol?
    private var timer: Timer?
    private var connectionFailed = false
    
    init( _ appStateManager:AppStateManager, vpnGateWay:VpnGatewayProtocol? ){
        self.appStateManager = appStateManager
        super.init()
        self.vpnGateway = vpnGateWay
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        return;
        guard vpnGateway != nil else { return }
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: VpnGateway.connectionChanged, object: nil)
        reachability?.whenReachable = { [weak self] _ in self?.connectionChanged() }
        reachability?.whenUnreachable = { [weak self] _ in self?.viewController?.displayUnreachable() }
        try? reachability?.startNotifier()
        
        viewController?.connectButton.addTarget(self, action: #selector(connectAction(_:)), for: .touchUpInside)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        viewController?.electronContainer?.animate()
        displayConnectoinState()
        return;        
        guard vpnGateway != nil else {
            viewController?.connectionIcon?.tintColor = .protonGreen()
            viewController?.connectionLabel.attributedText = LocalizedString
                .logInToUseWidget
                .attributed(withColor: .protonWhite(), font: .systemFont(ofSize: 16, weight: .regular))
            viewController?.connectButton.customState = .primary
            viewController?.setConnectButtonTitle(LocalizedString.logIn)
            return
        }
        
        connectionChanged()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // refresh data
        ProfileManager.shared.refreshProfiles()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reset()
    }
    
    deinit { reachability?.stopNotifier() }
    
    // MARK: - Utils
    
    @objc private func connectionChanged() {
        timer?.invalidate()
        timer = nil
     
        if let reachability = reachability, reachability.connection == .none {
            viewController?.displayUnreachable()
            return
        }
            
        viewController?.connectButton.isHidden = false
        
        guard let vpnGateway = vpnGateway else { return }

        switch vpnGateway.connection {
        case .connected:
            connectionFailed = false
            viewController?.connectionIcon?.tintColor = UIColor.protonGreen()
            viewController?.connectButton.customState = .destructive
            viewController?.setConnectButtonTitle(LocalizedString.disconnect)
//            viewController?.electronContainer?.stopAnimating()
            displayConnectoinState()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { self?.displayConnectoinState() }
            }
            
        case .connecting:
            connectionFailed = false
            viewController?.connectionIcon?.tintColor = UIColor.protonGreen()
            viewController?.connectionLabel.attributedText = LocalizedString.connectingDotDotDot.attributed(withColor: UIColor.protonGreen(), font: .systemFont(ofSize: 16, weight: .bold))
            viewController?.connectButton.customState = .destructive
            viewController?.setConnectButtonTitle(LocalizedString.cancel)
//            viewController?.electronContainer?.animate()
            
        case .disconnected, .disconnecting:
            if connectionFailed { break }
            viewController?.connectionIcon?.tintColor = UIColor.protonUnavailableGrey()
            viewController?.connectionLabel.attributedText = LocalizedString.disconnected.attributed(withColor: UIColor.protonUnavailableGrey(), font: .systemFont(ofSize: 16, weight: .bold))
            viewController?.connectButton.customState = .primary
            viewController?.setConnectButtonTitle(LocalizedString.quickConnect)
//            viewController?.electronContainer?.stopAnimating()
        }
    }
    
    fileprivate func reset() {
        timer?.invalidate()
        timer = nil
        connectionFailed = false
        viewController?.displayBlank()
    }
    
    @objc private func connectAction(_ sender: Any) {
        
        guard let vpnGateway = vpnGateway else {
            connectionFailed = false
            // not logged in so open the app
            viewController?.extensionContext?.open(URL(string: "protonvpn://")!, completionHandler: nil)
            return
        }
        
        if connectionFailed {
            // error
            viewController?.extensionContext?.open(URL(string: "protonvpn://")!, completionHandler: nil)
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
    
    private func displayConnectoinState() {
        switch vpnGateway?.connection {
        case .connected:
            guard let server = vpnGateway?.activeServer else { break }
            let country = LocalizationUtility.countryName(forCode: server.countryCode)
            viewController?.displayConnected(appStateManager.activeIp, country: country)
            break
        default:
            break
        }
    }
}

extension TodayViewModel: ExtensionAlertServiceDelegate {
    func actionErrorReceived() {
        connectionFailed = true
        viewController?.displayError()
    }
}
