//
//  ProfileUtility.swift
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

enum ProfileUtilityOperationOutcome {
    case success([Profile])
    case nameInUse
}

public class ProfileUtility {
    
    public static func index(for serverType: ServerType) -> Int {
        switch serverType {
        case .standard:
            return 0
        case .secureCore:
            return 1
        case .p2p:
            return 2
        case .tor:
            return 3
        case .unspecified:
            return 4
        }
    }
    
    public static func serverType(for index: Int) -> ServerType {
        switch index {
        case 0:
            return .standard
        case 1:
            return .secureCore
        case 2:
            return .p2p
        case 3:
            return .tor
        default:
            return .unspecified
        }
    }
    
    static func profile(withName name: String, in profiles: [Profile]) -> Profile? {
        return profiles.filter { $0.name == name }.first
    }
    
    static func profile(withId id: String, in profiles: [Profile]) -> Profile? {
        return profiles.filter { $0.id == id }.first
    }
    
    static func existsProfile(withName name: String, in profiles: [Profile]) -> Bool {
        return profile(withName: name, in: profiles) != nil
    }
    
    static func profile(withServer server: ServerModel, in profiles: [Profile]) -> Profile? {
        for existingProfile in profiles {
            if case ServerOffering.custom(let sw) = existingProfile.serverOffering, sw.server == server {
                return existingProfile
            }
        }
        return nil
    }
    
    static func existsProfile(withServer server: ServerModel, in profiles: [Profile]) -> Bool {
        return profile(withServer: server, in: profiles) != nil
    }
    
    static func profile(withConfiguration profile: Profile, in profiles: [Profile]) -> Profile? {
        return profiles.filter { $0.serverType == profile.serverType && $0.serverOffering == profile.serverOffering }.first
    }
    
    static func existsProfile(withConfiguration existingProfile: Profile, in profiles: [Profile]) -> Bool {
        return profile(withConfiguration: existingProfile, in: profiles) != nil
    }
    
    static func createProfile(with server: ServerModel, in profiles: [Profile]) -> ProfileUtilityOperationOutcome {        
        let accessTier = server.tier
        let serverType: ServerType = server.isSecureCore ? .secureCore : .standard
        let serverOffering: ServerOffering = .custom(ServerWrapper(server: server))
        let name = pickName(for: server, in: profiles)
        
        let colors = ProfileConstants.profileColors
        let color = colors[Int(arc4random_uniform(UInt32(colors.count)))]
        
        let profile = Profile(accessTier: accessTier, profileIcon: .circle(color.hexRepresentation), profileType: .user,
                              serverType: serverType, serverOffering: serverOffering, name: name)
        
        return .success(profiles + [profile])
    }
    
    static func createProfile(_ profile: Profile, in profiles: [Profile], at index: Int? = nil) -> ProfileUtilityOperationOutcome {
        if existsProfile(withName: profile.name, in: profiles) {
            return .nameInUse
        }
        
        if let index = index, index >= 0, index <= profiles.count {
            var updatedProfiles = profiles
            updatedProfiles.insert(profile, at: index)
            return .success(updatedProfiles)
        } else {
            return .success(profiles + [profile])
        }
    }
    
    static func updateProfile(_ profile: Profile, in profiles: [Profile]) -> ProfileUtilityOperationOutcome {
        let index: Int
        var updatedProfiles: [Profile] = profiles
        
        if let existingIndex = indexOfProfile(profile, in: profiles) {
            index = existingIndex
            updatedProfiles = delete(profile: profile, in: updatedProfiles)
        } else {
            index = profiles.count
        }
        
        return createProfile(profile, in: updatedProfiles, at: index)
    }
    
    static func delete(profile: Profile, in profiles: [Profile]) -> [Profile] {
        return profiles.filter { $0.id != profile.id }
    }
    
    // MARK: - Private static functions
    private static func indexOfProfile(_ profile: Profile, in profiles: [Profile]) -> Int? {
        for (index, element) in profiles.enumerated() where element.id == profile.id {
            return index
        }
        return nil
    }
    
    private static func pickName(for server: ServerModel, in profiles: [Profile]) -> String {
        var name = server.name
        var counter = 1
        
        while existsProfile(withName: name, in: profiles) {
            name = server.name + " (\(counter))"
            counter += 1
        }
        
        return name
    }
}
