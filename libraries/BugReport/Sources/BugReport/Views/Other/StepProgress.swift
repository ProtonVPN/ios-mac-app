//
//  Created on 2022-01-04.
//
//  Copyright (c) 2022 Proton AG
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

/// View representing progress of process that has steps.
@available(iOS 14.0, *)
struct StepProgress: View {
    var step: UInt
    var steps: UInt

    let colorMain: Color
    let colorSecondary: Color

    var barHeight: CGFloat = 2
    var font: Font = .system(size: 11)

    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Rectangle()
                    .fill(colorSecondary)

                GeometryReader { geo in
                    Rectangle()
                        .fill(colorMain)
                        .frame(maxWidth: geo.size.width * CGFloat(step) / CGFloat(steps))
                }
            }
            .frame(height: barHeight)

            Text(LocalizedString.stepOf(Int(step), Int(steps)))
                .font(font)
                .foregroundColor(colorMain)
                .padding(.horizontal)

        }
    }
}

// MARK: - Preview

@available(iOS 14.0, macOS 11, *)
struct StepProgress_Previews: PreviewProvider {
    static var previews: some View {
        StepProgress(step: 2, steps: 3, colorMain: .green, colorSecondary: .red)
            .preferredColorScheme(.dark)
    }
}
