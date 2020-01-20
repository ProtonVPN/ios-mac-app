//
//  ProfileManager.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

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

public class ProfileManager {
    
    public static var shared = ProfileManager(serverStorage: ServerStorageConcrete())
    
    public let contentChanged = Notification.Name("ProfileManagerContentChanged")
    
    public var customProfiles: [Profile] = []
    private var servers: [ServerModel] = []
    
    private init(serverStorage: ServerStorage) {
        NotificationCenter.default.addObserver(self, selector: #selector(profilesChanged(_:)),
                                               name: ProfileStorage.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(serversChanged(_:)),
                                               name: serverStorage.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(serversChanged(_:)),
                                               name: TrialChecker.trialExpired, object: nil)
        refreshProfiles()
    }
    
    public func refreshProfiles() {
        customProfiles = ProfileStorage.fetch()
    }
    
    public func profile(withServer server: ServerModel) -> Profile? {
        return ProfileUtility.profile(withServer: server, in: customProfiles)
    }
    
    public func profile(withId id: String) -> Profile? {
        return ProfileConstants.defaultProfiles.first {
            id == $0.id
        } ?? ProfileUtility.profile(withId: id, in: customProfiles)
    }
    
    public func existsProfile(withServer server: ServerModel) -> Bool {
        return ProfileUtility.existsProfile(withServer: server, in: customProfiles)
    }
    
    public func createProfile(withServer server: ServerModel) -> ProfileManagerOperationOutcome {
        let result = ProfileUtility.createProfile(with: server, in: customProfiles)
        switch result {
        case .success(let updatedProfiles):
            ProfileStorage.store(updatedProfiles)
        default:
            break
        }
        return ProfileManagerOperationOutcome(outcome: result)
    }
    
    public func createProfile(_ profile: Profile) -> ProfileManagerOperationOutcome {
        let result = ProfileUtility.createProfile(profile, in: customProfiles)
        switch result {
        case .success(let updatedProfiles):
            ProfileStorage.store(updatedProfiles)
        default:
            break
        }
        return ProfileManagerOperationOutcome(outcome: result)
    }
    
    public func updateProfile(_ profile: Profile) -> ProfileManagerOperationOutcome {
        let result = ProfileUtility.updateProfile(profile, in: customProfiles)
        switch result {
        case .success(let updatedProfiles):
            ProfileStorage.store(updatedProfiles)
        default:
            break
        }
        return ProfileManagerOperationOutcome(outcome: result)
    }
    
    public func deleteProfile(_ profile: Profile) {
        let updatedProfiles = ProfileUtility.delete(profile: profile, in: customProfiles)
        customProfiles = updatedProfiles
        ProfileStorage.store(updatedProfiles)
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
    
    @objc private func trialExpired(_ notification: Notification) {
        NotificationCenter.default.post(name: contentChanged, object: customProfiles)
    }
}
