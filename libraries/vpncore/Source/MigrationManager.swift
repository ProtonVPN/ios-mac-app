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

public typealias MigrationBlock = (( _ version: MigrationVersion, _ completion: OptionalErrorBlock) -> Void)

public protocol MigrationManagerProtocol {
    
    init( _ propertiesManager: PropertiesManager, currentAppVersion: String )
        
    mutating func addCheck( _ version: String, block: @escaping MigrationBlock )
    
    func migrate( _ completion: OptionalErrorBlock )
}

public struct MigrationManager: MigrationManagerProtocol {
    
    private let currentVersion: MigrationVersion
    private let propertiesManager: PropertiesManager
    
    private var migrationBlocks: [(String, MigrationBlock)] = []
    
    // MARK: - MigrationManagerProtocol
    
    public init(_ propertiesManager: PropertiesManager, currentAppVersion: String) {
        self.propertiesManager = propertiesManager
        self.currentVersion = MigrationVersion(currentAppVersion)
    }
    
    public mutating func addCheck(_ version: String, block: @escaping MigrationBlock) {
        self.migrationBlocks.append( ( version, block ) )
    }

    public func migrate(_ completion: OptionalErrorBlock) {
        migrate(completion, step: 0)
    }
    
    // MARK: - Private
    
    private func migrate( _ completion: OptionalErrorBlock, step: Int ) {
        if step >= migrationBlocks.count {
            propertiesManager.lastAppVersion = currentVersion
            completion(nil)
            return
        }
        
        let migrationVersion = MigrationVersion( migrationBlocks[step].0 )
        let block = migrationBlocks[step].1
        
        if migrationVersion > self.currentVersion {
            block( migrationVersion ) { error in
                guard let error = error else {
                    self.migrate(completion, step: step + 1)
                    return
                }
                completion(error)
            }
        } else {
            completion(nil)
        }
    }
}
