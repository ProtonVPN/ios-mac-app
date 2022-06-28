//
//  ServerStorageMock.swift
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

public class ServerStorageMock: ServerStorage {
    
    public var servers: [ServerModel]!

    public var age: TimeInterval = .hours(1)
    
    public var contentChanged = Notification.Name("ServerStorageContentChanged")
    
    public init(fileName: String, bundle: Bundle) {
        parseFromJsonFile(fileName, bundle: bundle)
    }

    public init(servers: [ServerModel] = []) {
        self.servers = servers
    }
    
    public func fetch() -> [ServerModel] {
        return servers
    }

    public func fetchAge() -> TimeInterval {
        age
    }
    
    public func store(_ newServers: [ServerModel]) {
        servers = newServers
    }
    
    public func update(continuousServerProperties: ContinuousServerPropertiesDictionary) {
        fatalError("\(#function) not implemented")
    }
    
    // MARK: - Private
    private func parseFromJsonFile(_ fileName: String, bundle: Bundle) {
        guard let serverJsonPath = bundle.path(forResource: fileName, ofType: "json") else {
            fatalError("Couldn't find servers file")
        }
        
        let jsonDictionary: JSONDictionary
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: serverJsonPath))
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: .mutableLeaves)
            guard let jsonDict = jsonObject as? JSONDictionary else {
                throw NSError()
            }
            jsonDictionary = jsonDict
        } catch {
            fatalError("Error loading JSON servers")
        }

        guard let serversJson = jsonDictionary.jsonArray(key: "LogicalServers") else {
            fatalError()
        }

        var serverModels: [ServerModel] = []
        for json in serversJson {
            do {
                serverModels.append(try ServerModel(dic: json))
            } catch {
                let error = ParseError.serverParse
                log.error("Failed to parse serves in mock with \(error)")
            }
        }

        self.servers = serverModels
    }
}
