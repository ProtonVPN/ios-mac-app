//
//  Created on 13/12/2022.
//
//  Copyright (c) 2022 Proton AG
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
import LocalFeatureFlags

enum TelemetryFeature: String, FeatureFlag {
    var category: String {
        "Telemetry"
    }

    var feature: String {
        rawValue
    }

    case telemetryOptIn = "TelemetryOptIn"
}

class TelemetryService {
    public typealias Factory = NetworkingFactory

    private let networking: Networking

    lazy var telemetryAPI: TelemetryAPI = TelemetryAPI(networking: networking)

    public convenience init(_ factory: Factory) {
        self.init(networking: factory.makeNetworking())
    }

    init(networking: Networking) {
        self.networking = networking
    }

    func report(event: ConnectionEvent) async {
        guard isEnabled(TelemetryFeature.telemetryOptIn) else { return }
        await telemetryAPI.flushEvent(event: event)
    }
}

class TelemetryAPI {

    private let networking: Networking

    init(networking: Networking) {
        self.networking = networking
    }

    func flushEvent(event: ConnectionEvent) async {
        let request = TelemetryRequest(event)
        do {
            try await withCheckedThrowingContinuation { continuation in
                networking.apiService.perform(request: request) { task, result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            // failed sending the events, do nothing
        }
    }
}
