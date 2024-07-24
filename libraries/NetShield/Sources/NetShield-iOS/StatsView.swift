//
//  Created on 11/06/2023.
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

import NetShield
import SwiftUI

struct StatsView: View {
    @State var isHovered = false

    var statsViewHeight: CGFloat = 64

    let model: NetShieldModel.Stat

    public var body: some View {
        VStack(alignment: .center) {
            Text(model.value)
                .themeFont(.body2(emphasised: true))
                .foregroundColor(valueForegroundColor())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(model.title)
                .themeFont(.overline())
                .foregroundColor(titleForegroundColor())
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, idealHeight: statsViewHeight)
        .onHover { isHovered = $0 }
        .background(
            RoundedRectangle(cornerRadius: .themeRadius4)
                .fill(backgroundColor())
        )
//        .help(model.help)
    }

    func valueForegroundColor() -> Color {
        Color(.text,
              model.isEnabled ? .normal : .hint)
    }

    func titleForegroundColor() -> Color {
        Color(.text,
              model.isEnabled ? .weak : .hint)
    }

    func backgroundColor() -> Color {
        if isHovered {
            return Color(.background, [.transparent, .hovered])
        }
        return .clear
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView(model: .random)
            .background(RoundedRectangle(cornerRadius: .themeRadius8)
                .fill(Color(.background, .weak)))
            .background(Color(.background))
            .previewLayout(.sizeThatFits)
    }
}

private extension NetShieldModel.Stat {
    static var random: NetShieldModel.Stat {
        .init(value: "\(Int.random(in: 1...1000))",
              title: "Trackers\nstopped",
              help: "",
              isEnabled: .random())
    }
}
