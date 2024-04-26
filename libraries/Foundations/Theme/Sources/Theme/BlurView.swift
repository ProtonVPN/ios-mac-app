//
//  Created on 20/04/2023.
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

/// This view is left here only for educational/experimenting purpose
@available(macOS 12.0, *)
private struct BlurView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.red, .blue],
                           startPoint: .top,
                           endPoint: .bottom)
            .ignoresSafeArea()
            VStack {
                MaterialsSetView()
                Spacer()
                MaterialsSetView()
            }
        }
    }
}

@available(macOS 12.0, *)
private struct MaterialsSetView: View {
    var body: some View {
        HStack {
            #if !os(tvOS)
            MaterialView(title: "bar", material: .bar)
            #endif
            MaterialView(title: "ultra\nThin", material: .ultraThinMaterial)
            MaterialView(title: "thin", material: .translucentLight)
            MaterialView(title: "regular", material: .regularMaterial)
            MaterialView(title: "thick", material: .translucentStrong)
            MaterialView(title: "ultra\nThick", material: .ultraThickMaterial)
        }
    }
}

@available(macOS 12.0, *)
private struct MaterialView: View {
    var title: String
    var material: Material
    var body: some View {
        Text(title)
            .padding(.init(top: 100, leading: 10, bottom: 100, trailing: 10))
            .background(material,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

@available(macOS 12.0, *)
struct BlurView_Previews: PreviewProvider {
    static var previews: some View {
        BlurView()
    }
}
