//
//  Created on 08/01/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import Dependencies
import Foundation
import Strings

@Reducer
public struct OfferBannerFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        let imageURL: URL
        let endTime: Date
        let showCountdown: Bool
        let buttonURL: URL
        let offerReference: String?

        var timeLeftString: String?

        public var id: String { offerReference ?? buttonURL.absoluteString }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case updateTimeRemaining
        case buttonTapped
        case dismissTapped

        case openUpgradeURL(URL, offerReference: String?)
        case dismiss
    }

    private enum CancelID {
        case timer
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) private var date
    @Dependency(\.locale) private var locale
    @Dependency(\.timeZone) private var timeZone

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                state.timeLeftString = getTimeLeft(endTime: state.endTime, formatter: relativeDateTimeFormatter)
                return startTimer(endTime: state.endTime)

            case .updateTimeRemaining:
                state.timeLeftString = getTimeLeft(endTime: state.endTime, formatter: relativeDateTimeFormatter)
                return .none

            case .buttonTapped:
                print("Offer banner button tapped: \(state.buttonURL)")
                return .send(.openUpgradeURL(state.buttonURL, offerReference: state.offerReference))

            case .dismissTapped:
                print("Offer banner dismissed")
                return .send(.dismiss)

            case .binding:
                return .none

            case .openUpgradeURL, .dismiss:
                return .none
            }
        }
    }

    // MARK: - Private Methods

    private func startTimer(endTime: Date) -> Effect<Action> {
        let timeLeft = endTime.timeIntervalSince(date.now)
        let refreshInterval: Duration = (timeLeft < 120)
            ? .seconds(1)
            : .minutes(1)

        return .run { [clock] send in
            for await _ in clock.timer(interval: refreshInterval) {
                await send(.updateTimeRemaining)
            }
        }
        .cancellable(id: CancelID.timer)
    }

    private var relativeDateTimeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        formatter.locale = locale
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        formatter.calendar = calendar
        return formatter
    }

    private func getTimeLeft(endTime: Date, formatter: RelativeDateTimeFormatter) -> String? {
        let timeLeft = endTime.timeIntervalSince(date.now)
        guard timeLeft >= 0 else {
            return nil
        }

        let string = formatter.localizedString(fromTimeInterval: timeLeft)
        return Localizable.offerEnding(string)
    }
}
