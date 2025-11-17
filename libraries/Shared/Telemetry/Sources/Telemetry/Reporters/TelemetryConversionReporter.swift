//
//  Created on 14.11.2025 by John Biggs.
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

#if canImport(AdAttributionKit)
    import AdAttributionKit
#endif

import Dependencies
import Ergonomics
import ProtonCorePaymentsV2

struct ConversionValue: RawRepresentable, OptionSet {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    init(bitPosition: Int) {
        assert(bitPosition < 6, "Value must be < 64")
        self = Self(rawValue: 1 << bitPosition)
    }

    static let signedIn = ConversionValue(bitPosition: 0)
    static let firstAction = ConversionValue(bitPosition: 1)
    static let yearlyPlan = ConversionValue(bitPosition: 2)
    static let unlimited = ConversionValue(bitPosition: 3)
    // bitPosition 4 is reserved for other plans
    static let paidSubscription = ConversionValue(bitPosition: 5)
    static let empty: Self = []

    #if canImport(AdAttributionKit)
        @available(iOS 17.4, *)
        var coarseValue: CoarseConversionValue {
            // If the user has paid for a subscription, the coarse value is high.
            if contains(.paidSubscription) {
                return .high
            }

            // Otherwise, if the user hasn't paid, but has engaged in an action, the coarse value is medium.
            if contains(.firstAction) {
                return .medium
            }

            // In all other cases, the coarse value is low.
            return .low
        }
    #endif
}

public struct TelemetryConversionReporter {
    public init() {}

    private func post(_ value: ConversionValue, lock: Bool = false, caller: StaticString = #function) {
        #if canImport(AdAttributionKit)
            guard #available(iOS 17.4, *) else {
                log.info("Not sending postback value \(value.rawValue): AAK unavailable")
                return
            }

            Task {
                do {
                    try await Postback.updateConversionValue(
                        Int(value.rawValue),
                        coarseConversionValue: value.coarseValue,
                        lockPostback: lock
                    )
                    log.info("Sent AAK postback for \(caller): \(value.rawValue) (\(value.coarseValue))")
                } catch {
                    log.error("Couldn't send AAK postback \(value.rawValue) (\(value.coarseValue)) for \(caller): \(error)")
                }
            }
        #else
            log.info("Not sending postback value \(value.rawValue): AAK unavailable")
        #endif
    }

    public func onboardingEvent(_ event: OnboardingEvent.Event) {
        var conversionValue: ConversionValue = .empty

        @Dependency(\.authKeychain) var keychain
        if let creds = keychain.fetch(), !creds.isCredentialLess {
            conversionValue.insert(.signedIn)
        }

        switch event {
        case .firstLaunch, .onboardingStart:
            break
        case .firstConnection:
            conversionValue.insert(.firstAction)
        default:
            // Don't send postback for these
            return
        }

        post(conversionValue)
    }

    public func upsellEvent(_ event: UpsellEvent.Event, newPlanName: String?, cycle: Int?) {
        guard case .success = event, let newPlanName, let cycle else {
            return
        }

        var conversionValue: ConversionValue = [.signedIn, .paidSubscription]

        if newPlanName.contains("bundle") {
            conversionValue.insert(.unlimited)
        }

        if cycle > 1 {
            conversionValue.insert(.yearlyPlan)
        }

        post(conversionValue, lock: true)
    }
}
