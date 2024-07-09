//
//  Created on 13/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import protocol GoLibs.LocalAgentNativeClientProtocol

protocol LocalAgentClient: LocalAgentNativeClientProtocol {
    var delegate: LocalAgentClientDelegate? { get set }
}

protocol LocalAgentClientDelegate: AnyObject {
    func didReceive(event: LocalAgentEvent)
}

struct LocalAgentClientFactory: DependencyKey {
    var createLocalAgentClient: () -> LocalAgentClient

    init(createLocalAgentClient: @escaping () -> LocalAgentClient) {
        self.createLocalAgentClient = createLocalAgentClient
    }

    static let liveValue: LocalAgentClientFactory = .init(createLocalAgentClient: { LocalAgentClientImplementation() })
}

extension DependencyValues {
    var localAgentClientFactory: LocalAgentClientFactory {
        get { self[LocalAgentClientFactory.self] }
        set { self[LocalAgentClientFactory.self] = newValue }
    }
}
