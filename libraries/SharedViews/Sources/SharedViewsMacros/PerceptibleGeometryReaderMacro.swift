//
//  Created on 02/10/2024.
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
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion

public struct PerceptibleGeometryReaderMacro: ExpressionMacro {

    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {

        guard let closure = node.trailingClosure else {
            throw MacroError.missingTrailingClosure
        }

        guard let signature = closure.signature else {
            throw MacroError.missingSignature
        }

        return """
        GeometryReader { \(signature)
            WithPerceptionTracking {
                 \(closure.statements)
            }
        }
        """
    }

    enum MacroError: Error, CustomStringConvertible {
        case missingTrailingClosure
        case missingSignature

        var description: String {
            switch self {
            case .missingTrailingClosure:
                return "\(PerceptibleGeometryReaderMacro.self) expects child views to be passed using a trailing closure."

            case .missingSignature:
                return "\(PerceptibleGeometryReaderMacro.self) expects the trailing closure signature to define the GeometryProxy argument."
            }
        }
    }
}
