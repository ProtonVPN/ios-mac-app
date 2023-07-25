//
//  Created on 2022-02-03.
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

public protocol UpdateCheckerFactory {
    func makeUpdateChecker() -> UpdateChecker
}

/// Check if updates for current app is available. Implemented on each platform depending on the way the app is distributed.
public protocol UpdateChecker {

    /// Check if current app can be updated.
    func isUpdateAvailable(_ callback: @escaping (Bool) -> Void)

    /// Start updating app.
    func startUpdate()
    
}
