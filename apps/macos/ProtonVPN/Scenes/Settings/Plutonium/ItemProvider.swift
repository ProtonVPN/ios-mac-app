//
//  Created on 2025-05-14 by Pawel Jurczyk.
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

import Foundation
import UniformTypeIdentifiers

/// NSItemProvider is not Sendable, we need to wrap it in a Sendable type.
public struct ItemProvider: @unchecked Sendable {
    public var provider: NSItemProvider { _provider.clone() }

    private var _provider: NSItemProvider

    public init(provider: NSItemProvider) {
        self._provider = provider
    }
}

extension NSItemProvider {
    fileprivate func clone() -> NSItemProvider {
        // swiftlint:disable:next force_cast
        copy() as! NSItemProvider
    }
}

extension ItemProvider {
    public func loadFileURL() async -> URL? {
        guard let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
              let data = item as? Data,
              let url = URL(dataRepresentation: data, relativeTo: nil) else {
            return nil
        }
        return url
    }
}
