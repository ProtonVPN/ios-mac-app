//
//  Created on 2022-01-17.
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
import BugReport

public protocol DynamicBugReportStorageFactory {
    func makeDynamicBugReportStorage() -> DynamicBugReportStorage
}

public protocol DynamicBugReportStorage {
    func fetch() -> BugReportModel?
    func store(_ bugReport: BugReportModel)
    func clear()
}

public class DynamicBugReportStorageUserDefaults: DynamicBugReportStorage {
    
    private let userDefaults: Storage
    private let storageKey: String = "DynamicBugReport"
    
    public init(userDefaults: Storage) {
        self.userDefaults = userDefaults
    }
    
    public func fetch() -> BugReportModel? {
        userDefaults.getDecodableValue(BugReportModel.self, forKey: storageKey)
    }
    
    public func store(_ bugReport: BugReportModel) {
        userDefaults.setEncodableValue(bugReport, forKey: storageKey)
    }
    
    public func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }
    
}
