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
    // This wasn't a singleton before, but we had issues with multiple NetworkPathMonitor living simultaneously
    public static let shared = NetworkPathMonitor()

    public private(set) var pathSubject: CurrentValueSubject<NWPath, Never>

    public var currentPath: NWPath {
        networkMonitor.currentPath
    }

    private let networkMonitor: NWPathMonitor

    private init() {
        let monitor = NWPathMonitor()
        self.networkMonitor = monitor
        self.pathSubject = .init(monitor.currentPath)
    }

    // This likely won't be called anymore since it's now a singleton, but let's keep it so we won't forget it if we switch back to the old implementation
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
