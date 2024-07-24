//
//  Created on 23/03/2023.
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
import Theme

public struct NetShieldStatsView: View {

    @ObservedObject public var viewModel = NetShieldModel(trackers: 0, ads: 0, data: 0, enabled: false)

    public var body: some View {
        HStack(spacing: 0) {
            StatsView(model: $viewModel.ads)
            StatsView(model: $viewModel.trackers)
            StatsView(model: $viewModel.data)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: .themeRadius8)
            .fill(Color(.background, .weak)))
    }
    public init() {

    }
}

struct StatsView: View {
    @State var isHovered = false

    var statsViewHeight: CGFloat = 56
    var statsViewWidth: CGFloat = 80

    @Binding var model: NetShieldModel.Stat

    public var body: some View {
        VStack(alignment: .center) {
            Text(model.value)
                .themeFont(.title3(emphasised: true))
                .foregroundColor(valueForegroundColor())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(model.title)
                .themeFont(.footnote())
                .foregroundColor(titleForegroundColor())
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
        }
        .frame(width: statsViewWidth, height: statsViewHeight)
        .onHover { isHovered = $0 }
        .background(
            RoundedRectangle(cornerRadius: .themeRadius4)
                .fill(backgroundColor())
        )
        .help(model.help)
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

struct NetShieldStatsView_Previews: PreviewProvider {
    static var view = NetShieldStatsView()
    static var previews: some View {
        view
            .background(Color(.background))
            .previewLayout(.sizeThatFits)
            .onAppear {
                view.viewModel = .random
            }
    }
}
