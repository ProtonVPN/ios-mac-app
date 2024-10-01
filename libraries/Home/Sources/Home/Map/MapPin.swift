//
//  Created on 10/09/2024.
//
//  Copyright (c) 2024 Proton AG
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

@available(iOS 17.0, *)
public struct MapPin: View {

    var mode: Mode

    var isMinimized: Bool { [.hop, .connecting].contains(mode) }

    public init(mode: Mode) {
        self.mode = mode
    }

    public var body: some View {
        ZStack {
            externalGradientCircle
                .scaleEffect(isMinimized ? 0 : 1)
                .opacity(isMinimized ? 0 : 1)
            externalCircle
                .scaleEffect(isMinimized ? 0.5 : 1)
            innerCircle
                .scaleEffect(isMinimized ? 0.5 : 1)
        }
    }

    var innerCircle: some View {
        Circle()
            .fill(mode.color)
            .frame(width: 12, height: 12)
    }

    var externalCircle: some View {
        Circle()
            .fill(.white)
            .frame(width: 24, height: 24)
            .shadow(color: .black.opacity(0.4), radius: 4, x: 0.0, y: 1)
    }

    var externalGradientCircle: some View {
        Circle()
            .fill(RadialGradient(colors: [mode.color,
                                          mode.color.opacity(0.01)],
                                 center: .center,
                                 startRadius: 96,
                                 endRadius: 0))
            .opacity(0.5)
            .frame(width: 96, height: 96)
            .phaseAnimator(AnimationPhase.allCases) { content, phase in
                content
                    .scaleEffect(phase.scaleEffect)
                    .rotationEffect(phase.rotationEffect)
            } animation: { $0.animation }
    }
}

@available(iOS 17.0, *)
public extension MapPin {
    enum Mode {
        case exitConnected
        case connecting
        case disconnected
        case hop

        var color: Color {
            switch self {
            case .exitConnected: Color(.icon, .vpnGreen)
            case .connecting: Color(.icon, .danger)
            case .disconnected: Color(.icon, .danger)
            case .hop: Color(.background, [.interactive, .active])
            }
        }
    }
}

private enum AnimationPhase: CaseIterable {
    case initial
    case wait
    case scale

    var animation: Animation {
        switch self {
        case .wait:
            return .easeInOut(duration: 2)
        case .initial:
            return .smooth(duration: 0.75)
        case .scale:
            return .easeInOut(duration: 0.75)
        }
    }

    var scaleEffect: Double {
        switch self {
        case .wait, .initial:
            1
        case .scale:
            0.8
        }
    }

    // This effect only exist to delay the next step
    var rotationEffect: Angle {
        switch self {
        case .wait:
            return .degrees(180)
        case .initial:
            return .degrees(90)
        case .scale:
            return .degrees(0)
        }
    }
}

// MARK: - Preview

@available(iOS 17, *)
#Preview {
    return WrapperView()
}

@available(iOS 17.0, *)
struct WrapperView: View {
    /*@Previewable*/ @State var mode: MapPin.Mode = .exitConnected

    var body: some View {
        VStack {
            MapPin(mode: mode)
            Button { withAnimation { mode = .exitConnected } } label: { Text("exitConnected") }
            Button { withAnimation { mode = .connecting } } label: { Text("connecting") }
            Button { withAnimation { mode = .disconnected } } label: { Text("disconnected") }
            Button { withAnimation { mode = .hop } } label: { Text("hop") }
        }
    }
}

// MARK: -
