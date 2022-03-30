//
//  Created on 29.03.2022.
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

import Foundation

protocol ReviewDataStorage: AnyObject {
    var successConnenctionsInARowCount: Int { get set }
    var lastReviewShownTimestamp: Date? { get set }
    var activeConnectionStartTimestamp: Date? { get set }
    var firstSuccessConnectionStartTimestamp: Date? { get set }

    func clear()
}

final class UserDefaultsReviewDataStorage: ReviewDataStorage {
    private enum Keys: String, CaseIterable {
        case successConnenctionsInARowCount
        case lastReviewShownTimestamp
        case activeConnectionStartTimestamp
        case firstSuccessConnectionStartTimestamp
    }

    var successConnenctionsInARowCount: Int {
        get {
            userDefaults.integer(forKey: Keys.successConnenctionsInARowCount.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.successConnenctionsInARowCount.rawValue)
        }
    }
    var lastReviewShownTimestamp: Date? {
        get {
            userDefaults.date(forKey: Keys.lastReviewShownTimestamp.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastReviewShownTimestamp.rawValue)
        }
    }
    var activeConnectionStartTimestamp: Date? {
        get {
            userDefaults.date(forKey: Keys.activeConnectionStartTimestamp.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.activeConnectionStartTimestamp.rawValue)
        }
    }
    var firstSuccessConnectionStartTimestamp: Date? {
        get {
            userDefaults.date(forKey: Keys.firstSuccessConnectionStartTimestamp.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.firstSuccessConnectionStartTimestamp.rawValue)
        }
    }

    private let userDefaults: UserDefaults

    convenience init() {
        self.init(userDefaults: UserDefaults.standard)
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func clear() {
        for key in Keys.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
    }
}
