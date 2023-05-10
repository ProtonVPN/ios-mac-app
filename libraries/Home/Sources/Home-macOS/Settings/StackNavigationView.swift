//
//  Created on 08/05/2023.
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

struct StackNavigationView<RootContent>: View where RootContent: View {
    @Binding var currentSubview: AnyView?
    @Binding var subviewTitle: String
    var title: String

    let rootView: () -> RootContent

    init(currentSubview: Binding<AnyView?>,
         subviewTitle: Binding<String>,
         title: String,
         @ViewBuilder rootView: @escaping () -> RootContent) {
        self._currentSubview = currentSubview
        self._subviewTitle = subviewTitle
        self.title = title
        self.rootView = rootView
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                    .frame(width: 20)
                if currentSubview != nil {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            currentSubview = nil
                        }
                    }, label: {
                        Asset.icChevronLeft.swiftUIImage
                            .resizable()
                            .foregroundColor(Color(.text))
                            .frame(width: 16, height: 16)
                    })
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
                    .frame(width: 12)
                Text(currentSubview != nil ? subviewTitle : title)
                    .font(.themeFont(.title1(emphasised: true)))
                    .foregroundColor(Color(.text))
                Spacer()
            }
            Spacer()
            if currentSubview == nil {
                rootView()
            } else {
                currentSubview
                .transition(.move(edge: .trailing))
            }
            Spacer()
        }
    }
}
