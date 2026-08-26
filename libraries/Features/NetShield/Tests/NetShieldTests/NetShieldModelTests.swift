//
//  Created on 26/08/2026 by Max Kupetskyi.
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

@testable import NetShieldShared
import Testing

@Suite("NetShieldModel equality")
struct NetShieldModelTests {
    @Test("Two models with the same counters are equal")
    func sameCountersAreEqual() {
        let model = NetShieldModel(trackersCount: 12, adsCount: 34, dataSaved: 56, enabled: true)
        let same = NetShieldModel(trackersCount: 12, adsCount: 34, dataSaved: 56, enabled: true)

        #expect(model == same)
    }

    /// Guards the counter comparison against a return to comparing `ads`, `trackers`, and `data`.
    @Test("Counts that abbreviate to the same display string are still different models")
    func abbreviatedCountsAreNotEqual() {
        let model = NetShieldModel(trackersCount: 0, adsCount: 1_000_001, dataSaved: 0, enabled: true)
        let other = NetShieldModel(trackersCount: 0, adsCount: 1_000_002, dataSaved: 0, enabled: true)

        #expect(model.ads.value == other.ads.value, "precondition: both counts abbreviate the same way")
        #expect(model != other)
    }

    @Test("Byte counts that format to the same display string are still different models")
    func roundedDataSavedIsNotEqual() {
        let model = NetShieldModel(trackersCount: 0, adsCount: 0, dataSaved: 1_000_000_001, enabled: true)
        let other = NetShieldModel(trackersCount: 0, adsCount: 0, dataSaved: 1_000_000_002, enabled: true)

        #expect(model.data.value == other.data.value, "precondition: both byte counts format the same way")
        #expect(model != other)
    }

    @Test("Turning NetShield off changes the model")
    func enabledParticipatesInEquality() {
        let enabled = NetShieldModel(trackersCount: 1, adsCount: 2, dataSaved: 3, enabled: true)

        #expect(enabled != enabled.copy(enabled: false))
    }

    @Test("A zeroed model keeps the enabled flag it was given")
    func zeroKeepsEnabledFlag() {
        #expect(NetShieldModel.zero(enabled: true) != NetShieldModel.zero(enabled: false))
    }
}
