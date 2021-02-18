//
//  MigrationManager.swift
//  vpncore - Created on 23/07/2020.
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
//

import Foundation

public typealias OptionalErrorBlock = ((Error?) -> Void)

/// The MigrationBlock contains the previous version of the App from which we updated and a completion block for asynchronous migration process

public typealias MigrationBlock = (( _ version: String, _ completion: @escaping OptionalErrorBlock) -> Void)

public protocol MigrationManagerProtocol {
    
    init( _ propertiesManager: PropertiesManagerProtocol, currentAppVersion: String )
    
    func addCheck( _ version: String, block: @escaping MigrationBlock ) -> MigrationManagerProtocol
    
    func migrate( _ completion: @escaping OptionalErrorBlock )
}

public protocol MigrationManagerFactory {
    func makeMigrationManager() -> MigrationManagerProtocol
}

public class MigrationManager: NSObject, MigrationManagerProtocol {
    
    private let currentVersion: MigrationVersion
    private let propertiesManager: PropertiesManagerProtocol
    
    private var migrationBlocks: [(String, MigrationBlock)] = []
    
    // MARK: - MigrationManagerProtocol
    
    public required init(_ propertiesManager: PropertiesManagerProtocol, currentAppVersion: String) {
        self.propertiesManager = propertiesManager
        self.currentVersion = MigrationVersion(currentAppVersion)
        super.init()
    }
    
    /// Add a migration step where the version specified has to be GREATER than the previous version in order to be executed
    /// Usually when adding a new check will be added specifying the new version to update
    public func addCheck(_ version: String, block: @escaping MigrationBlock) -> MigrationManagerProtocol {
        self.migrationBlocks.append( ( version, block ) )
        return self
    }
    
    /// Perform all the checks in the migration process and give a callback response once it's finished which can contain an error
    public func migrate(_ completion: @escaping OptionalErrorBlock) {
        migrate(completion, step: 0)
    }
    
    // MARK: - Private
    
    private func migrate( _ completion: @escaping OptionalErrorBlock, step: Int ) {
        if step >= migrationBlocks.count {
            propertiesManager.lastAppVersion = currentVersion
            completion(nil)
            return
        }
        
        let migrationVersion = MigrationVersion( migrationBlocks[step].0 )
        let block = migrationBlocks[step].1
        
        if migrationVersion > self.propertiesManager.lastAppVersion {
            block( self.propertiesManager.lastAppVersion.versionString ) { error in
                guard let error = error else {
                    self.migrate(completion, step: step + 1)
                    return
                }
                completion(error)
            }
        } else {
            self.migrate(completion, step: step + 1)
        }
    }
}
