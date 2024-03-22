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
import Strings

/// View representing progress of process that has steps.
struct StepProgress: View {
    var step: UInt
    var steps: UInt

    let colorMain: Color
    let colorText: Color
    let colorSecondary: Color

    var barHeight: CGFloat = 4
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
            .cornerRadius(16)

            Text(Localizable.stepOf(Int(step), Int(steps)))
                .font(font)
                .foregroundColor(colorText)
                .padding(.horizontal)

        }
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

// MARK: - Preview

struct StepProgress_Previews: PreviewProvider {
    static var previews: some View {
        StepProgress(step: 2, steps: 3, colorMain: .green, colorText: .purple, colorSecondary: .red)
            .preferredColorScheme(.dark)
    }
}
