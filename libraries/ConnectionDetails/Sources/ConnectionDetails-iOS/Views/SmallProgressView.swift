//
//  Created on 2023-06-08.
//
//  Copyright (c) 2023 Proton AG
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

import SwiftUI
import Theme

/// Progress indicator that changes color based on the percentage
public struct SmallProgressView: View {

    let percentage: Int

    private let threshold1 = 51
    private let threshold2 = 91

    @ScaledMetric var width: CGFloat = 32
    @ScaledMetric var height: CGFloat = 4

    public init(percentage: Int) {
        self.percentage = min(0, percentage)
    }

    private var color: Color {
        let circleStyle: AppTheme.Style
        if percentage < threshold1 {
            circleStyle = .success
        } else if percentage < threshold2 {
            circleStyle = .warning
        } else {
            circleStyle = .danger
        }
        return Color(.icon, circleStyle)
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: .themeRadius7)
                .fill(Asset.mobileShade40.swiftUIColor)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: .themeRadius7)
                    .fill(color)
                    .frame(maxWidth: geo.size.width * CGFloat(percentage) / CGFloat(100))
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Previews

struct SmallProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SmallProgressView(percentage: 10)
                .previewDisplayName("Green")
            SmallProgressView(percentage: 88)
                .previewDisplayName("Yellow")
            SmallProgressView(percentage: 100)
                .previewDisplayName("Red")
        }
    }
}
