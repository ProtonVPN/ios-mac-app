//
//  Created on 2026-02-02 by Pawel Jurczyk.
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

import SwiftUI

public struct LoadView: View {
    let load: Int
    let fraction: Double

    enum Dimensions {
        static let barHeight = CGFloat.themeSpacing4
        static let barWidth = CGFloat.themeSpacing32
        static let viewWidth: CGFloat = 78
    }

    public init(load: Int) {
        self.load = load
        self.fraction = Double(load) / 100
    }

    public var body: some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: Dimensions.barWidth, height: Dimensions.barHeight)
                .overlay(
                    HStack(spacing: 0) {
                        Capsule()
                            .fill(load.loadColor)
                            .frame(width: max(Dimensions.barHeight, Dimensions.barWidth * fraction))
                        Spacer(minLength: 0)
                    }
                )
            Spacer()
                .frame(width: .themeSpacing8)
            Text("\(load)%")
                .foregroundColor(Color(.text, .weak))
            Spacer(minLength: 0)
        }
        .frame(width: Dimensions.viewWidth)
    }
}

extension Int {
    var loadColor: Color {
        switch self {
        case 90...:
            Color(.icon, .danger)
        case 75 ..< 90:
            Color(.icon, .warning)
        default:
            Color(.icon, .success)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading) {
        ForEach([1, 2, 10, 25, 74, 75, 76, 89, 90, 91, 100], id: \.self) { load in
            LoadView(load: load)
        }
    }
    .padding()
    .background(Color(.background, .weak))
    .colorScheme(.dark)
}
