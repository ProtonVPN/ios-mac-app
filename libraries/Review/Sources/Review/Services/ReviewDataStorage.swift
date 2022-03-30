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
            UserDefaults.standard.integer(forKey: Keys.successConnenctionsInARowCount.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.successConnenctionsInARowCount.rawValue)
        }
    }
    var lastReviewShownTimestamp: Date? {
        get {
            UserDefaults.standard.date(forKey: Keys.lastReviewShownTimestamp.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.lastReviewShownTimestamp.rawValue)
        }
    }
    var activeConnectionStartTimestamp: Date? {
        get {
            UserDefaults.standard.date(forKey: Keys.activeConnectionStartTimestamp.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.activeConnectionStartTimestamp.rawValue)
        }
    }
    var firstSuccessConnectionStartTimestamp: Date? {
        get {
            UserDefaults.standard.date(forKey: Keys.firstSuccessConnectionStartTimestamp.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.firstSuccessConnectionStartTimestamp.rawValue)
        }
    }

    func clear() {
        for key in Keys.allCases {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
    }
}
