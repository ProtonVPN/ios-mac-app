//
//  Created on 30.06.2026 by John Biggs.
//
//  Copyright (c) 2026 Proton AG
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

import Strings
import SwiftUI
import Theme

/// The pill that expands over a selected city's pin, offering to connect. The overlay positions it at the pin's
/// projected point each frame, so it tracks the globe. `reveal` drives a capsule mask over the full-size pill, growing
/// it center-out from the pin's disc (0) to full size (1); the same value reversed collapses it back into the disc.
/// Tapping it connects.
struct ConnectPill: View, Animatable {
    var reveal: CGFloat
    let city: CityPin
    /// Projected pin location, or `nil` when the pin is behind the globe.
    let center: CGPoint?
    /// Called when the pill is tapped. The overlay turns hit testing off for the outgoing pill, so only the selected
    /// city's pill can fire this.
    var onTap: () -> Void = {}

    private enum Constants {
        /// The flag and label fade out early in the collapse, so they never peek out of the shrinking central reveal.
        static let contentFadeStart: CGFloat = 0.7
        static let contentFadeEnd: CGFloat = 0.95
    }

    private enum Dimensions {
        /// The mask starts and ends at the settled pin-disc diameter, so the pill grows out of and collapses back into
        /// exactly the dot it replaces.
        static let seed = PinDisplay.singleDiscDiameter
        static let height: CGFloat = 30
        static let horizontalPadding: CGFloat = 12
        /// Gap between the flag and the label, in points.
        static let flagGap: CGFloat = 6
    }

    var animatableData: CGFloat {
        get { reveal }
        set { reveal = newValue }
    }

    var body: some View {
        if let center, reveal > 0.001 {
            pill
                .mask(revealMask)
                .contentShape(Capsule())
                .position(center)
                .onTapGesture(perform: onTap)
        }
    }

    /// The full-size pill: the country flag and the connect label over a capsule styled like the pin
    /// discs, so the pill grows out of a disc that looks exactly like the one it replaces.
    private var pill: some View {
        HStack(spacing: Dimensions.flagGap) {
            if let code = city.countryCode {
                SimpleFlagView(regionCode: code, flagSize: .desktopRecentsSize)
            }
            Text("\(Localizable.actionConnect) – \(city.localizedName)")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color(.text, .inverted))
                .lineLimit(1)
                .fixedSize()
        }
        .opacity(ramp(reveal, from: Constants.contentFadeStart, to: Constants.contentFadeEnd))
        .padding(.horizontal, Dimensions.horizontalPadding)
        .frame(height: Dimensions.height)
        .background(Capsule().fill(PinDisplay.fillColor))
        .overlay(Capsule().stroke(PinDisplay.strokeColor, lineWidth: PinDisplay.strokeWidth))
    }

    /// A centered capsule interpolating from the disc-sized dot to the pill's own size, so the mask reveals
    /// the full-size pill center-out instead of scaling it.
    private var revealMask: some View {
        GeometryReader { proxy in
            Capsule()
                .frame(
                    width: max(Dimensions.seed, lerp(Dimensions.seed, proxy.size.width, reveal)),
                    height: max(Dimensions.seed, lerp(Dimensions.seed, proxy.size.height, reveal))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
