//
//  Created on 2022-01-07.
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

@available(iOS 14.0, macOS 11, *)
struct ResultView: View {
    var error: Error?
    var finishCallback: (() -> Void)?
    var retryCallback: (() -> Void)?
    var troubleshootCallback: (() -> Void)?

    @Environment(\.colors) var colors: Colors

    var body: some View {
        guard let error = error else {
            return AnyView(successBody)
                #if os(iOS)
                .navigationBarBackButtonHidden(true)
                #endif
        }

        return AnyView(
            ZStack {
                colors.background.ignoresSafeArea()

                VStack {
                    VStack(spacing: 8) {
                        FinalIcon(state: .failure)
                            .padding(.bottom, 32)
                        Text(LocalizedString.brFailureTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(error.localizedDescription)
                            .font(.body)
                    }
                    .foregroundColor(colors.textPrimary)
                    .frame(maxHeight: .infinity, alignment: .center)

                    Spacer()

                    VStack {
                        Button(action: { retryCallback?() }, label: { Text(LocalizedString.brFailureButtonRetry) })
                            .buttonStyle(PrimaryButtonStyle())

                        Button(action: { troubleshootCallback?() }, label: { Text(LocalizedString.brFailureButtonTroubleshoot) })
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)

                }
            })
            #if os(iOS)
            .navigationBarBackButtonHidden(true)
            #endif
    }

    var successBody: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack {
                VStack(spacing: 8) {
                    FinalIcon(state: .success)
                        .padding(.bottom, 32)
                    Text(LocalizedString.brSuccessTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(LocalizedString.brSuccessSubtitle)
                        .font(.body)
                }
                .foregroundColor(colors.textPrimary)
                .frame(maxHeight: .infinity, alignment: .center)

                Button(action: { finishCallback?() }, label: { Text(LocalizedString.brSuccessButton) })
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Preview

@available(iOS 14.0, macOS 11, *)
struct ResultView_Previews: PreviewProvider {
    static var previews: some View {
        ResultView(error: nil)
            .preferredColorScheme(.dark)
        ResultView(error: NSError(domain: "abc", code: 123, userInfo: nil))
            .preferredColorScheme(.dark)
    }
}
