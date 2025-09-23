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

#if REDESIGN

    // MARK: - Start SwiftUI Life cycle

    import ComposableArchitecture
    import Home
    import LegacyCommon
    import Logging
    import SwiftUI
    import Theme
    import VPNAppCore

    let log: Logging.Logger = .init(label: "ProtonVPN.logger")

    @main
    struct ProtonVPNApp: App {
        @Environment(\.scenePhase) var scenePhase

        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

        @State private var window: NSWindow?

        let appReducer: StoreOf<AppReducer>

        init() {
            self.appReducer = .init(initialState: .loading, reducer: {
                AppReducer()
                    .dependency(\.vpnConnectionStatusPublisher, VPNConnectionStatusPublisherKey.watchVPNConnectionStatusChanges)
                    ._printChanges()
            })
            appDelegate.navigationService.sendAction = { [appReducer] action in
                appReducer.send(action)
            }
        }

        var body: some Scene {
            WindowGroup {
                SwitchStore(appReducer) { state in
                    switch state {
                    case .loggedIn:
                        CaseLet(/AppReducer.State.loggedIn, action: AppReducer.Action.app) { appStore in
                            SideBarView(store: appStore)
                        }
                        .onAppear {
                            NSWindow.allowsAutomaticWindowTabbing = false
                        }
                        .navigationTitle("")
                        .background(WindowAccessor(window: $window, windowType: .app)) // get access to the underlying NSWindow
                        .task {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    case .notLoggedIn:
                        CaseLet(/AppReducer.State.notLoggedIn, action: AppReducer.Action.showLogin) { appStore in
                            LoginViewControllerRepresentable(
                                store: appStore,
                                loginViewModel: LoginViewModel(
                                    factory: appDelegate.container,
                                    initialError: nil
                                )
                            )
                        }
                        .preferredColorScheme(.dark)
                        .onAppear {
                            NSWindow.allowsAutomaticWindowTabbing = false
                        }
                        .background(WindowAccessor(window: $window, windowType: .login)) // get access to the underlying NSWindow
                        .task {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    case .loading:
                        EmptyView()
                    }
                }
            }
            .windowToolbarStyle(UnifiedWindowToolbarStyle())
            .windowStyle(HiddenTitleBarWindowStyle())
            .appCommands(appDelegate: appDelegate, store: appReducer)
            .onChange(of: scenePhase, perform: scenePhaseChanged) // The SwiftUI lifecycle events
            .defaultPosition(.center)

            MenuBarExtra("MenuBarExtra", systemImage: "hammer") {
                EmptyView()
            }
            .menuBarExtraStyle(.window)
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
            commands {
                CommandGroup(after: .appInfo) {
                    Button("Check for updates") {
                        appDelegate.navigationService.checkForUpdates()
                    }
                    Divider()
                    Button("Settings...") { // TODO: add translation
                        appDelegate.navigationService.openSettings(to: .general)
                    }.keyboardShortcut(",", modifiers: [.command])
                }
                CommandGroup(before: .appTermination) {
                    Button("Sign out") {
                        appDelegate.navigationService.logOutRequested()
                    }.keyboardShortcut("w", modifiers: [.command, .shift])
                }
                CommandGroup(before: .toolbar) {
                    Button("Toggle Connection Details") {
                        store.send(.app(.home(.showConnectionDetails)))
                    }
                }
                CommandGroup(before: .help) {
                    Button("Report an Issue...") {
                        appDelegate.navigationService.showReportBug()
                    }

                    Button("View Logs") {}
                    Button("OpenVPN Logs") {}
                    Button("WireGuard Logs") {}
                    Button("Clear Application Data") {}
                    Button("System Extension Tutorial") {}
                }
                CommandGroup(replacing: .newItem, addition: {}) // block user from opening multiple windows
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

        func makeNSView(context _: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                window = view.window
                configureForWindowType()
            }
            return view
        }

        func configureForWindowType() {
            window?.title = "Proton VPN"
            window?.centerWindowOnScreen()
            switch windowType {
            case .app:
                window?.isOpaque = false
                window?.setContentSize(.init(width: 780, height: 580)) // default size for the app window
                window?.backgroundColor = .clear
            case .login:
                window?.setContentSize(.init(width: 1, height: 1)) // content size managed by autolayout, we just want to force the minimal size
                window?.backgroundColor = .color(.background)
            }
        }

        func updateNSView(_: NSView, context _: Context) {
            log.debug("updateNSView")
        }
    }

#endif
