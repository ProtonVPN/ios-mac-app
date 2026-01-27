//
//  Created on 27/01/2026 by Max Kupetskyi.
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

import Cocoa

let app = NSApplication.shared

let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

if isRunningTests,
   let testDelegateClass = NSClassFromString("ProtonVPNmacOSTests.TestAppDelegate") as? NSObject.Type,
   let testDelegate = testDelegateClass.init() as? NSApplicationDelegate {
    // Use a minimal delegate for tests to speed up test execution
    // and avoid side effects from the full app initialization
    app.delegate = testDelegate
} else {
    let appDelegate = AppDelegate()
    app.delegate = appDelegate
}

app.run()
