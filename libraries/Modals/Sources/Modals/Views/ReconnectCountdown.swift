//
//  Created on 01.09.23.
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

import Foundation
import SwiftUI
import Theme

public struct ReconnectCountdown: View {
    static let timerQuantum = 0.1

    @State private var currentTime: Date = Date()

    /// The time when the timer should finish.
    let dateFinished: Date
    /// The total duration of the timer (to know how much of the progress ring to draw).
    let timeInterval: TimeInterval

    var timeSince: TimeInterval {
        dateFinished.timeIntervalSince(currentTime)
    }

    var displayTimeRemaining: TimeInterval {
        let amount = timeSince
        return amount > 0 ? amount : 0
    }

    let checkmarkAnimationDuration: TimeInterval = 1
    var checkmarkStrokeRatio: Double {
        let amount = -dateFinished.timeIntervalSince(currentTime)
        guard amount > 0 else {
            return 0
        }
        guard amount < checkmarkAnimationDuration else {
            return 1
        }

        return amount / checkmarkAnimationDuration
    }
    var checkmarkStrokeRatioInDegrees: Double {
        checkmarkStrokeRatio * .degreesInACircle
    }

    var isFinished: Bool {
        displayTimeRemaining == 0
    }

    var ratioWaited: Double {
        (displayTimeRemaining) / timeInterval
    }

    var ratioWaitedInDegrees: Double {
        ratioWaited * .degreesInACircle
    }

    let timer = Timer.publish(every: timerQuantum, on: .main, in: .common).autoconnect()

    var progressCircles: some View {
        ZStack {
            Circle()
                .stroke(style: .countdown)
                .foregroundColor(Color(.background, [.interactive, .weak]))
            Circle()
                .trim(from: 0, to: ratioWaited)
                .rotation(.degrees(270))
                .stroke(style: .countdown)
                .foregroundColor(Color(.icon, [.interactive, .active]))
                .animation(.linear(duration: Self.timerQuantum).delay(Self.timerQuantum * 2), value: timeSince)
            Circle()
                .trim(from: 0, to: checkmarkStrokeRatio)
                .stroke(style: .countdown)
                .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
                .rotationEffect(.degrees(270))
                .foregroundColor(Color(.icon, .success))
                .animation(.linear(duration: Self.timerQuantum).delay(Self.timerQuantum * 2), value: timeSince)
        }
    }

    var checkmark: some View {
        GeometryReader { geometry in
            let (width, height) = (geometry.size.width, geometry.size.height)
            let startX: Double = (1 / 3 - 1 / 16) * width
            let startY: Double = (9 / 16) * height
            let tipX: Double = (7 / 16) * width
            let tipY: Double = (2 / 3 + 1 / 16) * height
            let endX: Double = (5 / 6 - 1 / 16) * width
            let endY: Double = (1 / 6 + 1 / 16) * height

            Path { path in
                path.move(to: .init(x: startX, y: startY))
                path.addLine(to: .init(x: tipX, y: tipY))
                path.addLine(to: .init(x: endX, y: endY))
            }
            .trim(from: 0, to: checkmarkStrokeRatio)
            .stroke(style: .countdown)
            .animation(.linear(duration: 0.1).delay(Self.timerQuantum * 2), value: timeSince)
            .foregroundColor(Color(.text))
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !isFinished {
                    Text(displayTimeRemaining.timerString)
                    #if os(iOS)
                        .themeFont(.body1(.bold))
                    #elseif os(macOS)
                        .themeFont(.title2(emphasised: true))
                    #endif
                        .foregroundColor(Color(.text))
                        .position(.center(of: geometry.size))
                }
                checkmark
                    .frame(geometry.size.minSquare.scaled(by: 0.6))
                    .position(.center(of: geometry.size))
            }
        }
        .overlay(progressCircles)
        .frame(width: 88, height: 88)
        .padding(StrokeStyle.countdown.lineWidth / 2)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}


extension TimeInterval {
    var components: (hours: Int, minutes: Int, seconds: Int) {
        let hours = Int(self) / (60 * 60)
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60

        return (hours, minutes, seconds)
    }

    var timerString: String {
        let time = components

        guard time.hours > 0 else {
            return String(
                format: "%02i:%02i",
                time.minutes, time.seconds
            )
        }

        return String(
            format: "%02i:%02i:%02i",
            time.hours, time.minutes, time.seconds
        )
    }
}

fileprivate extension Double {
    static let degreesInACircle: Self = 360
}

fileprivate extension CGPoint {
    static func center(of size: CGSize) -> Self {
        .init(x: size.width / 2, y: size.height / 2)
    }
}

fileprivate extension CGSize {
    var minSquare: Self {
        .init(width: min(width, height), height: min(width, height))
    }

    func scaled(by scale: CGFloat) -> Self {
        .init(width: width * scale, height: height * scale)
    }
}

fileprivate extension View {
    func frame(_ frame: CGSize) -> some View {
        self.frame(width: frame.width, height: frame.height)
    }
}

fileprivate extension StrokeStyle {
    static let countdown: Self = .init(lineWidth: 10, lineCap: .square, lineJoin: .miter)
}

struct RotationTimer_Previews: PreviewProvider {
    static let duration: TimeInterval = 5
    static let date = Date()

    static var previews: some View {
        ReconnectCountdown(
            dateFinished: date.addingTimeInterval(duration),
            timeInterval: duration
        )
        .frame(width: 86, height: 86)
    }
}
