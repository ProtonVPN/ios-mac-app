//
//  SecureCoreEntryCountryModel.swift
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

import CoreLocation
import UIKit
import LegacyCommon
import Localization
import Strings

class SecureCoreEntryCountryModel: AnnotationViewModel, Hashable {
    
    private let appStateManager: AppStateManager
    private var vpnGateway: VpnGatewayProtocol
    
    var buttonStateChanged: (() -> Void)?
    
    let countryCode: String
    private(set) var exitCountryCodes: Set<String> = []
    let coordinate: CLLocationCoordinate2D
    
    var isConnected: Bool {
        if vpnGateway.connection == .connected, let activeServer = appStateManager.activeConnection()?.server, activeServer.serverType == .secureCore, activeServer.countryCode == countryCode {
            return true
        }
        return false
    }
    
    var isConnecting: Bool {
        if let activeConnection = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting, case ConnectionRequestType.country(let activeCountryCode, _) = activeConnection.connectionType, activeCountryCode == countryCode {
            return true
        }
        return false
    }
    
    var available: Bool = true
    
    var viewState: AnnotationViewState = .idle {
        didSet {
            if oldValue != viewState { // to prevent excessive draw calls
                buttonStateChanged?()
            }
        }
    }
    
    let outlineColor: UIColor = .brandColor()
    let connectIconTint: UIColor = .clear
    let connectIcon: UIImage? = nil
    
    let minPinHeight: CGFloat = 36
    let maxPinHeight: CGFloat = 36
    
    var anchorPoint: CGPoint {
        return CGPoint(x: 0.5, y: (maxPinHeight * 0.5) / maxHeight)
    }
    
    var labelHeight: CGFloat {
        return 30
    }
    
    var labelString: NSAttributedString {
        return Localizable.viaCountry(LocalizationUtility.default.countryName(forCode: countryCode) ?? "").attributed(withColor: .normalTextColor(), fontSize: 18, alignment: .center)
    }
    
    var labelColor: UIColor {
        return UIColor.brandColor().withAlphaComponent(0.75)
    }
    
    var flagOverlayColor: UIColor {
        return UIColor.brandColor().withAlphaComponent(0.25)
    }
    
    let showAnchor: Bool = false
    
    init(appStateManager: AppStateManager, countryCode: String, location: CLLocationCoordinate2D, vpnGateway: VpnGatewayProtocol) {
        self.appStateManager = appStateManager
        self.countryCode = countryCode
        self.coordinate = location
        self.vpnGateway = vpnGateway
    }
    
    func addExitCountryCode(_ code: String) {
        exitCountryCodes.insert(code)
    }
    
    func tapped() {
        return // don't respond to taps
    }
    
    func highlight(_ highlight: Bool) {
        if highlight && viewState == .idle {
            viewState = .selected
        } else if !highlight && viewState == .selected {
            viewState = .idle
        }
    }
    
    // MARK: - Hashable conformance
    static func == (lhs: SecureCoreEntryCountryModel, rhs: SecureCoreEntryCountryModel) -> Bool {
        return lhs.countryCode == rhs.countryCode
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(countryCode)
    }
}
