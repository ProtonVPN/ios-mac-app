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
import SwiftUI
import Perception

/// Functionally equivalent to wrapping `content` in `WithPerceptionTracking` and `GeometryReader` closures.
///
/// It was not possible to implement this with a `View`, since the `ViewBuilder` content must be evaluated according to
/// a `GeometryProxy` object, which means it has to be an escaping closure. This makes it impossible to wrap it with
/// a `WithPerceptionTracking` closure.
@freestanding(expression)
public macro PerceptibleGeometryReader<Content: View>(
    @ViewBuilder content: (GeometryProxy) -> Content
) -> GeometryReader<WithPerceptionTracking<Content>> = #externalMacro(
    module: "SharedViewsMacros",
    type: "PerceptibleGeometryReaderMacro"
)
