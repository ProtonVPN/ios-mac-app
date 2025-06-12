// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import Foundation

extension String {
    func splitToArray(separator: Character = ",", trimmingCharacters: CharacterSet? = nil) -> [String] {
        split(separator: separator)
            .map {
                if let charSet = trimmingCharacters {
                    $0.trimmingCharacters(in: charSet)
                } else {
                    String($0)
                }
            }
    }
}

extension String? {
    func splitToArray(separator: Character = ",", trimmingCharacters: CharacterSet? = nil) -> [String] {
        switch self {
        case .none:
            []
        case let .some(wrapped):
            wrapped.splitToArray(separator: separator, trimmingCharacters: trimmingCharacters)
        }
    }
}
