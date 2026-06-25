//
//  Created on 2026-05-12 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import SwiftUI
import Theme

public struct RecordingPin: View {
    public init() {}

    private static let innerCircleDiameter: CGFloat = 9
    private static let outerCircleDiameter: CGFloat = 24

    public var body: some View {
        ZStack {
            outerCircle
            innerCircle
        }
    }

    var innerCircle: some View {
        Circle()
            .fill(Color(.background, .danger))
            .frame(.square(Self.innerCircleDiameter))
    }

    var outerCircle: some View {
        Circle()
            .fill(Color(.background, .danger)).opacity(0.2)
            .frame(.square(Self.outerCircleDiameter))
    }
}
