//
//  Created on 07/06/2024.
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

import SnapshotTesting
import SwiftUI
import TestingErgonomics

extension AssertSnapshot {
    static var precision: Float { 0.99 }
    static var perceptualPrecision: Float { 0.98 }

    func snap(
        _ view: @autoclosure () throws -> some View,
        caseName: String,
        trait: UIUserInterfaceStyle,
        record recording: Bool? = nil,
        timeout: TimeInterval = 5,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName _: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        try assertSnapshot(
            of: view(),
            as: .image(
                precision: Self.precision,
                perceptualPrecision: Self.perceptualPrecision,
                traits: trait.collection
            ),
            record: recording,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: "\(caseName) \(trait.name)",
            line: line,
            column: column
        )
    }
}

extension UIUserInterfaceStyle {
    var name: String {
        switch self {
        case .light:
            return "light"
        case .dark:
            return "dark"
        case .unspecified:
            return "unspecified"
        @unknown default:
            return "unknown \(self)"
        }
    }

    var collection: UITraitCollection {
        UITraitCollection(userInterfaceStyle: self)
    }
}
