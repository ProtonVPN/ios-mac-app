//
//  Created on 12.07.23.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation

import Dependencies

import Domain

/// This exists because the `attemptSilentLogIn()` function needs to be overridden.
class AppSessionRefresherMock: AppSessionRefresherImplementation {
    var didAttemptLogin: (() -> Void)?
    var loginError: Error?

    override func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void) {
        defer { didAttemptLogin?() }

        if let loginError = loginError {
            completion(.failure(loginError))
            return
        }

        let isFreeTier: Bool
        do {
            isFreeTier = try vpnKeychain.fetchCached().maxTier.isFreeTier
        } catch {
            completion(.failure(error))
            return
        }

        withEscapedDependencies { dependencies in
            vpnApiService.refreshServerInfo(freeTier: isFreeTier) { result in
                dependencies.yield {
                    switch result {
                    case let .success(properties):
                        guard let properties else {
                            completion(.success)
                            return
                        }
                        if let userLocation = properties.location {
                            self.propertiesManager.userLocation = userLocation
                        }
                        if let services = properties.streamingServices {
                            self.propertiesManager.streamingServices = services.streamingServices
                        }
                        do {
                            if !isFreeTier {
                                let updatedServerIDs = properties.serverModels.reduce(into: Set<String>(), { $0.insert($1.id) })
                                let deletedServerCount = try self.serverRepository.delete(serversWithMinTier: 1, withIDsNotIn: updatedServerIDs)
                                log.info("Deleted \(deletedServerCount) stale paid servers", category: .persistence)
                            }
                            try self.serverRepository.upsert(servers: properties.serverModels.map { VPNServer(legacyModel: $0) })
                            completion(.success)
                        } catch {
                            completion(.failure(error))
                        }
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
}
