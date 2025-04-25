//
//  Created on 22/04/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
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

import Theme

struct HermesUpsellView: ExplicitlySizedView {
    static let viewSize: CGSize = .init(width: 520, height: 444)

    let upgradeAction: () -> Void

    var body: some View {
        VStack(spacing: 32.0) {
            VStack {
                Asset.hermesSplashScreen.swiftUIImage
                    .frame(width: 320, height: 180)

                Text("Advanced VPN customization")
                    .themeFont(.title1(emphasised: true))
                    .foregroundStyle(Color(.text, .normal))

                Text("Connect using Hermes with VPN Plus.")
                    .themeFont(.title2(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
            }

            Button("Upgrade", action: upgradeAction)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(EdgeInsets(top: 36, leading: 60, bottom: 64, trailing: 60))
        .frame(width: Self.viewSize.width, height: Self.viewSize.height)
        .background(Color(red: 22 / 255, green: 20 / 255, blue: 28 / 255))
        .background(linearGradientBackground)
    }

    private var linearGradientBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 170 / 255, green: 75 / 255, blue: 255 / 255, opacity: 0),
                Color(red: 17 / 255, green: 216 / 255, blue: 204 / 255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 320)
    }
}

final class HermesUpsellWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    init(action: @escaping () -> Void) {
        let mask: NSWindow.StyleMask = [.closable, .titled, .borderless, .fullSizeContentView]
        let windowRect = NSRect(origin: .zero, size: HermesUpsellView.viewSize)

        super.init(contentRect: windowRect, styleMask: mask, backing: .buffered, defer: false)

        let hermesView = HermesUpsellView(upgradeAction: action)
        let hostingViewController = ExplicitlySizedHostingController(rootView: hermesView)
        contentViewController = hostingViewController

        titlebarAppearsTransparent = true
        backgroundColor = .color(.background, .weak)
    }
}
