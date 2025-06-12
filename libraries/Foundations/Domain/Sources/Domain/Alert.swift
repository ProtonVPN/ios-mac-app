//
//  Created on 28/06/2024.
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

// MARK: - Definitions

public struct Alert: Equatable, Sendable {
    private static let titleFallback: LocalizedStringResource = "Error"
    private static let messageFallback: LocalizedStringResource = "An error occurred."

    public let title: LocalizedStringResource
    public let message: LocalizedStringResource

    init() {
        title = Self.titleFallback
        message = Self.messageFallback
    }

    init(title: LocalizedStringResource = Self.titleFallback, message: LocalizedStringResource = Self.messageFallback) {
        self.title = title
        self.message = message
    }

    public init(title: String? = nil, message: String? = nil) {
        self.title = title.flatMap { LocalizedStringResource(stringLiteral: $0) } ?? Self.titleFallback
        self.message = message.flatMap { LocalizedStringResource(stringLiteral: $0) } ?? Self.messageFallback
    }

    public init(localizedError: LocalizedError) {
        title = localizedError.failureReason.map { LocalizedStringResource(stringLiteral: $0) } ?? Self.titleFallback
        message = localizedError.errorDescription.map { LocalizedStringResource(stringLiteral: $0) } ?? Self.messageFallback
    }

    public func callAsFunction() -> Self {
        self
    }
}

/// An error meant to be displayed within an ``AlertService.Alert`` alert.
public protocol AlertConvertibleError: Error {
    var alert: Alert { get }
}
