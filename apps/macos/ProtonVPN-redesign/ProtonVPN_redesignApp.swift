//
//  Created on 25/04/2023.
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

// MARK: - Start SwiftUI Life cycle
import SwiftUI
import Theme
import Theme_macOS
import Home
import Home_macOS
import vpncore
import Logging

let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.logger")

@main
struct ProtonVPNApp: App {

    @Environment(\.scenePhase) var scenePhase

    @State private var window: NSWindow?

    var body: some Scene {
        WindowGroup {
            SideBarView()
                .background(WindowAccessor(window: $window)) // get access to the underlying NSWindow
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
                .navigationTitle("")

        }
        .windowToolbarStyle(UnifiedWindowToolbarStyle())
        .windowStyle(HiddenTitleBarWindowStyle())
        .onChange(of: scenePhase) { newScenePhase in // The SwiftUI lifecycle events
            switch newScenePhase {
            case .active:
                log.debug("App is active")
            case .inactive:
                log.debug("App is inactive")
            case .background:
                log.debug("App is in background")
            @unknown default:
                log.debug("Received an unexpected new value.")
            }
        }
        .commands {
            CommandGroup(replacing: .newItem, addition: { }) // block user from opening multiple windows
            CommandMenu("Custom Menu") {
                Button("Say Hello") {
                    log.debug("Hello")
                }
                .keyboardShortcut("h", modifiers: [.command])
            }
        }

    }
}
// MARK: - End SwiftUI Life cycle

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
            self.window?.isOpaque = false
            self.window?.backgroundColor = .clear
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        log.debug("updateNSView")
    }
}
