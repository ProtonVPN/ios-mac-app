//
//  Created on 03/02/2023.
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
import Theme_iOS

struct OnboardingButton: View {

    var completion: (() -> Void)?
    var geometry: GeometryProxy

    let framePadding: CGFloat = .themeSpacing16

    var body: some View {
        Spacer()
        Button {
            completion?()
        } label: {
            Text(LocalizedString.onboardingNext)
                .foregroundColor(Color(.text, .primary))
                .themeFont(.body1())
                .frame(minWidth: geometry.size.width - framePadding * 2,
                       minHeight: 48)
                .background(RoundedRectangle(cornerRadius: .themeRadius8)
                    .fill(Color(.background, .interactive)))
                .contentShape(RoundedRectangle(cornerRadius: .themeRadius8))
                .padding(.bottom)
        }

    }
}

struct OnboardingButton_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.background)
                    .ignoresSafeArea()
                VStack() {
                    OnboardingButton(geometry: geometry)
                }
            }
        }
    }
}
