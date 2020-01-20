//
//  StatusViewModel.swift
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

import Foundation
import GSMessages
import vpncore

class StatusViewModel {
    
    private let appSessionManager: AppSessionManager
    private let propertiesManager: PropertiesManagerProtocol
    private let profileManager: ProfileManager
    private let vpnGateway: VpnGatewayProtocol?
 
    weak var delegate: ConnectionBarViewModelDelegate?
    
    // Used to send GSMessages to a view controller
    var messageHandler: ((String, GSMessageType, [GSMessageOption]) -> Void)?
    var contentChanged: (() -> Void)?
    var dismissStatusView: (() -> Void)?
    
    var isSessionEstablished: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    var ipAddress: String {
        return formIpAddress()
    }
    
    private var timer: Timer?
    private var currentTime: String {
        return delegate?.timeString() ?? ""
    }
    
    init(appSessionManager: AppSessionManager,
         propertiesManager: PropertiesManagerProtocol,
         profileManager: ProfileManager,
         vpnGateway: VpnGatewayProtocol?,
         delegate: ConnectionBarViewModelDelegate) {
        self.appSessionManager = appSessionManager
        self.propertiesManager = propertiesManager
        self.profileManager = profileManager
        self.vpnGateway = vpnGateway
        self.delegate = delegate
        
        startObserving()
        runTimer()
    }
    
    deinit {
        stopObserving()
        timer?.invalidate()
    }
    
    var tableViewData: [TableViewSection] {
        let sections: [TableViewSection] = [
            locationSection,
            technicalDetailsSection,
            saveAsProfileSection
        ]
        
        return sections
    }
    
    private var locationSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .keyValue(key: LocalizedString.connectedTo, value: vpnGateway?.activeServer?.country ?? ""),
            secondaryLocationCell
        ]
        
        return TableViewSection(title: LocalizedString.location.uppercased(), cells: cells)
    }
    
    private var secondaryLocationCell: TableViewCellModel {
        if let type = vpnGateway?.activeServerType, type == .secureCore {
            if let entryCountryCode = vpnGateway?.activeServer?.entryCountryCode {
                return .keyValue(key: LocalizedString.via, value: LocalizationUtility.countryName(forCode: entryCountryCode) ?? "")
            } else {
                return .keyValue(key: LocalizedString.unavailable, value: LocalizedString.unavailable)
            }
        } else {
            return .keyValue(key: LocalizedString.city, value: vpnGateway?.activeServer?.city ?? "")
        }
    }
    
    private var technicalDetailsSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .keyValue(key: LocalizedString.ip, value: vpnGateway?.activeIp ?? ""),
            .keyValue(key: LocalizedString.server, value: vpnGateway?.activeServer?.name ?? ""),
            .keyValue(key: LocalizedString.sessionTime, value: currentTime)
        ]
        
        return TableViewSection(title: LocalizedString.technicalDetails.uppercased(), cells: cells)
    }
    
    private var saveAsProfileSection: TableViewSection {
        let cell: TableViewCellModel
        if let server = vpnGateway?.activeServer, profileManager.existsProfile(withServer: server) {
            cell = .button(title: LocalizedString.deleteProfile, accessibilityIdentifier:"Delete Profile", color: .protonRed(), handler: { [deleteProfile] in
                deleteProfile()
            })
        } else {
            cell = .button(title: LocalizedString.saveAsProfile, accessibilityIdentifier:"Save as Profile", color: .protonWhite(), handler: { [saveAsProfile] in
                saveAsProfile()
            })
        }
        
        return TableViewSection(title: "", cells: [cell])
    }
    
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: VpnGateway.connectionChanged, object: nil)
    }
    
    private func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func formIpAddress() -> String {
        let description: String
        
        if isSessionEstablished {
            guard let vpnGateway = vpnGateway else {
                return LocalizedString.unavailable
            }
            
            switch vpnGateway.connection {
            case .connected, .disconnecting:
                description = String(format: LocalizedString.ip, vpnGateway.activeIp ?? LocalizedString.unavailable)
            default:
                if let userIp = propertiesManager.userIp {
                    description = String(format: LocalizedString.publicIp, userIp)
                } else {
                    description = String(format: LocalizedString.publicIp, LocalizedString.unavailable)
                }
            }
        } else {
            description = String(format: LocalizedString.publicIp, LocalizedString.unavailable)
        }
        
        return description
    }
    
    @objc private func connectionChanged() {
        guard let vpnGateway = vpnGateway, vpnGateway.connection == .disconnected else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.dismissStatusView?()
        }
    }
    
    // MARK: Save as Profile
    private func saveAsProfile() {
        guard let server = vpnGateway?.activeServer,
              profileManager.profile(withServer: server) == nil else {
            PMLog.ET("Could not create profile because matching profile already exists")
            messageHandler?(LocalizedString.profileCreationFailed,
                            GSMessageType.error,
                            UIConstants.messageOptions)
            contentChanged?()
            return
        }
        
        _ = profileManager.createProfile(withServer: server)
        messageHandler?(LocalizedString.profileCreatedSuccessfully,
                        GSMessageType.success,
                        UIConstants.messageOptions)
        contentChanged?()
    }
    
    private func deleteProfile() {
        guard let server = vpnGateway?.activeServer,
              let existingProfile = profileManager.profile(withServer: server) else {
            PMLog.ET("Could not find profile to delete")
            messageHandler?(LocalizedString.profileDeletionFailed,
                            GSMessageType.error,
                            UIConstants.messageOptions)
            contentChanged?()
            return
        }
        
        profileManager.deleteProfile(existingProfile)
        messageHandler?(LocalizedString.profileDeletedSuccessfully,
                        GSMessageType.success,
                        UIConstants.messageOptions)
        contentChanged?()
    }
    
    private func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.timerFired)), userInfo: nil, repeats: true)
    }
    
    @objc private func timerFired() {
        contentChanged?()
    }
}
