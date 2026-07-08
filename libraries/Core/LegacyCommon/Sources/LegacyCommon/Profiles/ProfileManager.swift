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

import CommonNetworking
import Dependencies
import DependenciesMacros
import Domain
import Foundation
import Sharing
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

@DependencyClient
public struct ProfileManager {
    public var customProfiles: () -> [Profile] = { [] }
    public var defaultProfiles: () -> [Profile] = { [] }
    public var allProfiles: () -> [Profile] = { [] }
    public var autoConnectProfile: () -> Profile?
    public var quickConnectProfile: () -> Profile?

    public var refreshProfiles: () -> Void = {}
    public var profile: (_ id: String) -> Profile?
    public var createProfile: (_ profile: Profile) -> ProfileManagerOperationOutcome = { _ in .nameInUse }
    public var updateProfile: (_ profile: Profile) -> ProfileManagerOperationOutcome = { _ in .nameInUse }
    public var deleteProfile: (_ profile: Profile) -> Void
}

public final class ProfileManagerImplementation {
    public var customProfiles: [Profile] = []
    public var defaultProfiles: [Profile] {
        @Shared(.connectionProtocol) var connectionProtocol
        return ProfileConstants.defaultProfiles(connectionProtocol: connectionProtocol)
    }

    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.profileStorage) private var profileStorage

    public var allProfiles: [Profile] {
        defaultProfiles + customProfiles
    }

    public init() {
        refreshProfiles()
    }

    public func refreshProfiles() {
        customProfiles = profileStorage.fetch()
    }

    public var username: String? {
        @Dependency(\.authKeychain) var authKeychain
        return authKeychain.username
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

    public func profile(withId id: String) -> Profile? {
        defaultProfiles.first { id == $0.id } ?? ProfileUtility.profile(withId: id, in: customProfiles)
    }

    public func createProfile(_ profile: Profile) -> ProfileManagerOperationOutcome {
        let result = ProfileUtility.createProfile(profile, in: customProfiles)
        switch result {
        case let .success(updatedProfiles):
            profileStorage.store(profiles: updatedProfiles, storageVersion: .current)
            profilesChanged(updatedProfiles)
        default:
            break
        }
        return ProfileManagerOperationOutcome(outcome: result)
    }

    public func updateProfile(_ profile: Profile) -> ProfileManagerOperationOutcome {
        let result = ProfileUtility.updateProfile(profile, in: customProfiles)
        switch result {
        case let .success(updatedProfiles):
            profileStorage.store(profiles: updatedProfiles, storageVersion: .current)
            profilesChanged(updatedProfiles)
        default:
            break
        }
        return ProfileManagerOperationOutcome(outcome: result)
    }

    public func deleteProfile(_ profile: Profile) {
        let updatedProfiles = ProfileUtility.delete(profile: profile, in: customProfiles)
        profileStorage.store(profiles: updatedProfiles, storageVersion: .current)
        profilesChanged(updatedProfiles)
    }

    // MARK: - Private functions

    private func profilesChanged(_ profiles: [Profile]) {
        customProfiles = profiles
        AppEvent.profileContentChanged.post(customProfiles)
    }
}

public enum ProfileManagerKey: DependencyKey {
    public static var liveValue: ProfileManager = {
        let profileManagerImpl = ProfileManagerImplementation()
        return ProfileManager(
            customProfiles: { profileManagerImpl.customProfiles },
            defaultProfiles: { profileManagerImpl.defaultProfiles },
            allProfiles: { profileManagerImpl.allProfiles },
            autoConnectProfile: { profileManagerImpl.autoConnectProfile },
            quickConnectProfile: { profileManagerImpl.quickConnectProfile },
            refreshProfiles: { profileManagerImpl.refreshProfiles() },
            profile: { id in profileManagerImpl.profile(withId: id) },
            createProfile: { newProfile in profileManagerImpl.createProfile(newProfile) },
            updateProfile: { profile in profileManagerImpl.updateProfile(profile) },
            deleteProfile: { profileToDelete in profileManagerImpl.deleteProfile(profileToDelete) }
        )
    }()
}

public extension DependencyValues {
    var profileManager: ProfileManager {
        get { self[ProfileManagerKey.self] }
        set { self[ProfileManagerKey.self] = newValue }
    }
}
