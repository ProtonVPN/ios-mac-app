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
import Home
import Home_macOS
import vpncore
import Logging
import ComposableArchitecture
import VPNShared

let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.logger")

@main
struct ProtonVPNApp: App {

    @Environment(\.scenePhase) var scenePhase

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var window: NSWindow?

    let store: StoreOf<AppReducer>

    init() {
        @Dependency(\.initialStateProvider) var initialStateProvider

        self.store = .init(
            initialState: initialStateProvider.initialState,
            reducer: AppReducer()
                .dependency(\.watchVPNConnectionStatus, WatchAppStateChangesKey.watchVPNConnectionStatusChanges)
                ._printChanges()
        )
        appDelegate.navigationService.sendAction = { [store] action in
            store.send(action)
        }
    }

    var body: some Scene {
        WindowGroup {
            WithViewStore(store, observe: { $0 }) { viewStore in
                if viewStore.login.isLoggedIn {
                    SideBarView(store: store)
                        .preferredColorScheme(.light)
                        .onAppear {
                            NSWindow.allowsAutomaticWindowTabbing = false
                        }
                        .navigationTitle("")
                        .background(WindowAccessor(window: $window, windowType: .app)) // get access to the underlying NSWindow
                        .task {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                } else {
                    LoginViewControllerRepresentable(store: store.scope(state: \.login,
                                                                        action: AppReducer.Action.login),
                                                     loginViewModel: LoginViewModel(factory: appDelegate.container,
                                                                                    initialError: viewStore.login.initialError))
                        .preferredColorScheme(.dark)
                        .onAppear {
                            NSWindow.allowsAutomaticWindowTabbing = false
                        }
                        .background(WindowAccessor(window: $window, windowType: .login)) // get access to the underlying NSWindow
                        .task {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                }

            }
        }
        .windowToolbarStyle(UnifiedWindowToolbarStyle())
        .windowStyle(HiddenTitleBarWindowStyle())
        .appCommands(appDelegate: appDelegate, store: store)
        .onChange(of: scenePhase, perform: scenePhaseChanged) // The SwiftUI lifecycle events
        // .defaultPosition(.center) // macOS 13
        if #available(macOS 13.0, *) {
            MenuBarExtra("MenuBarExtra", systemImage: "hammer") {
                EmptyView()
            }
            .menuBarExtraStyle(.window)
        }
    }

    func scenePhaseChanged(newScenePhase: ScenePhase) {
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
}
// MARK: - End SwiftUI Life cycle

extension Scene {
    func appCommands(appDelegate: AppDelegate, store: StoreOf<AppReducer>) -> some Scene {
        self.commands {
            CommandGroup(after: .appInfo) {
                Button("Check for updates") {
                    appDelegate.navigationService.checkForUpdates()
                }
                Divider()
                Button("Settings...") { // todo: add translation
                    appDelegate.navigationService.openSettings(to: .general)
                }.keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(before: .appTermination) {
                Button("Sign out") {
                    appDelegate.navigationService.logOutRequested()
                }.keyboardShortcut("w", modifiers: [.command, .shift])
            }
            CommandGroup(before: .toolbar) {
                WithViewStore(store, observe: { $0.connectionDetailsVisible }) { store in
                    Button("Toggle Connection Details") {
                        store.send(.toggleConnectionDetails)
                    }
                }
            }
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

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    enum WindowType {
        case app
        case login
    }

    var windowType: WindowType {
        didSet {
            configureForWindowType()
        }
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
            configureForWindowType()
        }
        return view
    }

    func configureForWindowType() {
        self.window?.title = "Proton VPN"
        self.window?.centerWindowOnScreen()
        switch windowType {
        case .app:
            self.window?.isOpaque = false
            self.window?.setContentSize(.init(width: 780, height: 580)) // default size for the app window
            self.window?.backgroundColor = .clear
        case .login:
            self.window?.setContentSize(.init(width: 1, height: 1)) // content size managed by autolayout, we just want to force the minimal size
            self.window?.backgroundColor = .color(.background)
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        log.debug("updateNSView")
    }
}
