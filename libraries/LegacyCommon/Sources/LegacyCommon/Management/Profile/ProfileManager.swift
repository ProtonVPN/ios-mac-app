//
//  ProfileManager.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import Dependencies

import Domain
import VPNShared

public enum ProfileManagerOperationOutcome {
    
    case success
    case nameInUse
    
    init(outcome: ProfileUtilityOperationOutcome) {
        switch outcome {
        case .success:
            self = .success
        case .nameInUse:
            self = .nameInUse
        }
    }
}

public protocol ProfileManagerFactory {
    func makeProfileManager() -> ProfileManager
}

public class ProfileManager {
    @Dependency(\.authKeychain) var authKeychain

    public let contentChanged = Notification.Name("ProfileManagerContentChanged")

    public var customProfiles: [Profile] = []
    public var defaultProfiles: [Profile] {
        ProfileConstants.defaultProfiles(connectionProtocol: propertiesManager.connectionProtocol)
    }

    private var servers: [ServerModel] = []
    private let propertiesManager: PropertiesManagerProtocol
    private let profileStorage: ProfileStorage

    public var allProfiles: [Profile] {
        return defaultProfiles + customProfiles
    }

    public typealias Factory = ServerStorageFactory & PropertiesManagerFactory & ProfileStorageFactory

    public convenience init(_ factory: Factory) {
        self.init(serverStorage: factory.makeServerStorage(),
                  propertiesManager: factory.makePropertiesManager(),
                  profileStorage: factory.makeProfileStorage())
    }
    
    public init(serverStorage: ServerStorage,
                propertiesManager: PropertiesManagerProtocol,
                profileStorage: ProfileStorage) {
        self.propertiesManager = propertiesManager
        self.profileStorage = profileStorage

        NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged(_:)),
                                               name: ProfileStorage.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(serversChanged(_:)),
                                               name: serverStorage.contentChanged, object: nil)
        refreshProfiles()
    }
    
    public func refreshProfiles() {
        customProfiles = profileStorage.fetch()
    }

    public var username: String? {
        return authKeychain.username.value
    }

    public var autoConnectProfile: Profile? {
        guard let username else {
            return nil
        }
        let (enabled, profileID) = propertiesManager.getAutoConnect(for: username)
        guard enabled, let profileID else {
            return nil
        }
        return profile(withId: profileID)
    }

    public var quickConnectProfile: Profile? {
        guard let username else {
            return nil
        }
        guard let profileID = propertiesManager.getQuickConnect(for: username) else {
            return nil
        }
        return profile(withId: profileID)
    }
    public func profile(withServer server: ServerModel) -> Profile? {
        return ProfileUtility.profile(withServer: server, in: customProfiles)
    }
    
    public func profile(withId id: String) -> Profile? {
        return defaultProfiles.first { id == $0.id }
            ?? ProfileUtility.profile(withId: id, in: customProfiles)
    }
    
    public func existsProfile(withServer server: ServerModel) -> Bool {
        return ProfileUtility.existsProfile(withServer: server, in: customProfiles)
    }
    
    public func createProfile(withServer server: ServerModel, vpnProtocol: VpnProtocol, netShield: NetShieldType?) -> ProfileManagerOperationOutcome {
        let result = ProfileUtility.createProfile(with: server, vpnProtocol: vpnProtocol, netShield: netShield, in: customProfiles)
        switch result {
        case .success(let updatedProfiles):
            profileStorage.store(updatedProfiles)
        default:
            break
        }
        return ProfileManagerOperationOutcome(outcome: result)
    }
    
    public func createProfile(_ profile: Profile) -> ProfileManagerOperationOutcome {
        let result = ProfileUtility.createProfile(profile, in: customProfiles)
        switch result {
        case .success(let updatedProfiles):
            profileStorage.store(updatedProfiles)
        default:
            break
        }
        return ProfileManagerOperationOutcome(outcome: result)
    }
    
    @discardableResult public func updateProfile(_ profile: Profile) -> ProfileManagerOperationOutcome {
        let result = ProfileUtility.updateProfile(profile, in: customProfiles)
        switch result {
        case .success(let updatedProfiles):
            profileStorage.store(updatedProfiles)
        default:
            break
        }
        return ProfileManagerOperationOutcome(outcome: result)
    }
    
    public func deleteProfile(_ profile: Profile) {
        let updatedProfiles = ProfileUtility.delete(profile: profile, in: customProfiles)
        customProfiles = updatedProfiles
        profileStorage.store(updatedProfiles)
    }
    
    // MARK: - Private functions
    @objc private func profilesChanged(_ notification: Notification) {
        if let newProfiles = notification.object as? [Profile] {
            customProfiles = newProfiles
            NotificationCenter.default.post(name: contentChanged, object: customProfiles)
        }
    }
    
    @objc private func serversChanged(_ notification: Notification) {
        if let newServers = notification.object as? [ServerModel] {
            servers = newServers
            NotificationCenter.default.post(name: contentChanged, object: customProfiles)
        }
    }
}
