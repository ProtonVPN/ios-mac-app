//
//  Created on 2023-11-20.
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

// `NSApplicationMain` doesn't want to work with our redesigned app
// (or probably with fully SwiftUI app).
#if !REDESIGN

#import <Cocoa/Cocoa.h>

/**
 * Attempts to load and run the application with the specified AppDelegate class name.
 *
 * @param className The fully-qualified class name of the AppDelegate (e.g., "ProtonVPN.AppDelegate")
 * @return YES if the AppDelegate was successfully loaded and run, NO otherwise
 */
BOOL runAppDelegateWithClassName(NSString *className) {
    Class appDelegateClass = NSClassFromString(className);
    if (appDelegateClass == nil) {
        return NO;
    }
    
    id appDelegate = [[appDelegateClass alloc] init];
    [[NSApplication sharedApplication] setDelegate:appDelegate];
    [NSApp run];
    return YES;
}

int main(int argc, char *argv[]) {
    // Try loading AppDelegate from a test suite. This lets us make tests run faster
    // and not break tests.
    if (runAppDelegateWithClassName(@"ProtonVPNmacOSTests.TestAppDelegate")) {
        return 0;
    }

    // Then, try loading the proper AppDelegate for the main app
    if (runAppDelegateWithClassName(@"ProtonVPN.AppDelegate")) {
        return 0;
    }

    // Fallback
    return NSApplicationMain(argc, (const char **) argv);
}

#endif
