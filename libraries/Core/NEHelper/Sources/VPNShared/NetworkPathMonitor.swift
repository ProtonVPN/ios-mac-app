//
//  Created on 27/08/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Combine
import Network

public final class NetworkPathMonitor {
    public private(set) var pathSubject: CurrentValueSubject<NWPath, Never>

    public var currentPath: NWPath {
        networkMonitor.currentPath
    }

    private let networkMonitor: NWPathMonitor

    public init() {
        let monitor = NWPathMonitor()
        self.networkMonitor = monitor
        self.pathSubject = .init(monitor.currentPath)
    }

    deinit {
        stop()
    }

    public func start(onQueue queue: DispatchQueue) {
        // we need to recreate `pathSubject` if it was stopped before
        pathSubject = .init(networkMonitor.currentPath)
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.pathSubject.send(path)
        }
        networkMonitor.start(queue: queue)
    }

    public func stop() {
        pathSubject.send(completion: .finished)
        networkMonitor.cancel()
    }
}
