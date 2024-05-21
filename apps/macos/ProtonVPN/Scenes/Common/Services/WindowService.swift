//
//  WindowService.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa
import LegacyCommon
import SwiftUI
import BugReport
import AppKit
import PMLogger
import Strings
import Modals_macOS
import Dependencies

protocol WindowServiceFactory {
    func makeWindowService() -> WindowService
}

protocol WindowService: WindowControllerDelegate {

    func setStatusMenuWindowController(_ controller: StatusMenuWindowController)
    
    func showIfPresent<T: NSWindowController>(windowController: T.Type) -> Bool
    func closeIfPresent<T: NSWindowController>(windowController: T.Type)
    
    func showLogin(viewModel: LoginViewModel)
#if !REDESIGN
    func showSidebar(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol)
#endif
    
    func openAbout(factory: AboutViewController.Factory)
    func openAcknowledgements()
    func openSettingsWindow(viewModel: SettingsContainerViewModel, tabBarViewModel: SettingsTabBarViewModel, accountViewModel: AccountViewModel)
    func openProfilesWindow(viewModel: ProfilesContainerViewModel)
    func openReportBugWindow(viewModel: ReportBugViewModel, alertService: CoreAlertService)
    func openSystemExtensionGuideWindow(cancelledHandler: @escaping () -> Void)
    func openSubuserAlertWindow(alert: SubuserWithoutConnectionsAlert)
    
    func bringWindowsToForeground() -> Bool
    func closeActiveWindows(except: [NSWindowController.Type])
    
    func presentKeyModal(viewController: NSViewController)
    
    /// Check if window with view controller of the same class is already open.
    func isKeyModalPresent(viewController: NSViewController) -> Bool
}

extension WindowService {
    func closeActiveWindows() {
        closeActiveWindows(except: [])
    }
}

// this need to abstract class for common functions. for sharing code. ios/mac should have different implementation
class WindowServiceImplementation: WindowService {
    
    typealias Factory = CreateNewProfileViewModelFactory
        & NavigationServiceFactory
        & CountriesSectionViewModelFactory
        & MapSectionViewModelFactory
        & CoreAlertServiceFactory
        & PropertiesManagerFactory
        & AppStateManagerFactory
        & VpnGatewayFactory
        & HeaderViewModelFactory
        & AnnouncementsViewModelFactory
        & SystemExtensionManagerFactory
        & ConnectingOverlayViewModelFactory
        & NetShieldPropertyProviderFactory
        & ProfileManagerFactory
        & SafariServiceFactory
        & LogFileManagerFactory
        & BugReportCreatorFactory
        & DynamicBugReportManagerFactory
        & VpnKeychainFactory
        & SessionServiceFactory
        & PropertiesManagerFactory

    private let factory: Factory
    
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var bugReportCreator: BugReportCreator = factory.makeBugReportCreator()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    
    fileprivate var mainWindowController: WindowController?
    fileprivate var statusMenuWindowController: StatusMenuWindowController?
    fileprivate var activeWindowControllers = Set<WindowController>()
    
    init(factory: Factory) {
        self.factory = factory
    }
    
    func setStatusMenuWindowController(_ controller: StatusMenuWindowController) {
        controller.windowService = self
        statusMenuWindowController = controller
    }
    
    func showIfPresent<T: NSWindowController>(windowController: T.Type) -> Bool {
        var success = false
        for controller in activeWindowControllers {
            if let controller = controller as? T {
                controller.showWindow(self)
                success = true
                break
            }
        }
        return success
    }
    
    func closeIfPresent<T: NSWindowController>(windowController: T.Type) {
        for controller in activeWindowControllers {
            if let controller = controller as? T {
                controller.close()
            }
        }
    }
    
    func showLogin(viewModel: LoginViewModel) {
        NSApp.setActivationPolicy(.regular)
        
        if let windowController = mainWindowController {
            windowController.close()
        }
        
        let windowController = LoginWindowController(viewController: LoginViewController(viewModel: viewModel))
        windowController.delegate = self
        windowController.showWindow(self)
        windowController.window?.makeMain()
        
        mainWindowController = windowController
    }

#if !REDESIGN
    func showSidebar(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol) {
        NSApp.setActivationPolicy(.regular)
        
        if let windowController = mainWindowController {
            windowController.close()
        }
        
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let viewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Sidebar")) as! SidebarViewController
        viewController.appStateManager = appStateManager
        viewController.vpnGateway = vpnGateway
        viewController.navService = navService
        viewController.factory = factory
        
        let windowController = SidebarWindowController(viewController: viewController)
        windowController.delegate = self
        windowController.showWindow(self)
        windowController.window?.makeMain()
        
        mainWindowController = windowController
        showInitialModals()
    }

    func showInitialModals() {
        guard propertiesManager.showWhatsNewModal else {
            return
        }
        propertiesManager.showWhatsNewModal = false

        presentKeyModal(viewController: ModalsFactory.whatsNewViewController())
    }

#endif
    
    func openAbout(factory: AboutViewController.Factory) {
        let controller = AboutViewController()
        controller.factory = factory
        let windowController = AboutWindowController(viewController: controller)
        windowController.delegate = self
        activeWindowControllers.insert(windowController)
        windowController.showWindow(self)
    }
    
    func openAcknowledgements() {
        let windowController = AcknowledgementsWindowController(viewController: AcknowledgementsViewController())
        windowController.delegate = self
        activeWindowControllers.insert(windowController)
        windowController.showWindow(self)
    }
    
    func openSettingsWindow(viewModel: SettingsContainerViewModel, tabBarViewModel: SettingsTabBarViewModel, accountViewModel: AccountViewModel) {
        NSApp.setActivationPolicy(.regular)
        
        let viewController = SettingsContainerViewController(viewModel: viewModel, tabBarViewModel: tabBarViewModel, accountViewModel: accountViewModel)
        let windowController = SettingsWindowController(viewController: viewController)
        windowController.delegate = self
        activeWindowControllers.insert(windowController)
        windowController.showWindow(self)
    }
    
    func openProfilesWindow(viewModel: ProfilesContainerViewModel) {
        NSApp.setActivationPolicy(.regular)
        
        let viewController = ProfilesContainerViewController(factory: factory, viewModel: viewModel)
        let windowController = ProfilesWindowController(viewController: viewController)
        windowController.delegate = self
        activeWindowControllers.insert(windowController)
        windowController.showWindow(self)
    }
    
    func openReportBugWindow(viewModel: ReportBugViewModel, alertService: CoreAlertService) {
        NSApp.setActivationPolicy(.regular)
        
        let viewController: NSViewController
        let manager = factory.makeDynamicBugReportManager()
        
        let vc = bugReportCreator.createBugReportViewController(delegate: manager, colors: Colors())
        manager.closeBugReportHandler = { [weak self] in
            self?.closeWindow(withController: ReportBugWindowController.self)
        }
        viewController = vc
        viewController.title = Localizable.reportBug

        let windowController = ReportBugWindowController(viewController: viewController)
        windowController.delegate = self
        activeWindowControllers.insert(windowController)
        windowController.showWindow(self)
    }

    func openSystemExtensionGuideWindow(cancelledHandler: @escaping () -> Void) {
        let controller = SystemExtensionGuideViewController(cancelledHandler: cancelledHandler)
        controller.windowService = self
        let windowController = SysexGuideWindowController(viewController: controller)
        windowController.delegate = controller
        activeWindowControllers.insert(windowController)
        windowController.showWindow(self)
    }
    
    func openSubuserAlertWindow(alert: SubuserWithoutConnectionsAlert) {
        let controller = SubuserMacAlertViewController()
        controller.role = alert.role
        controller.safariServiceFactory = factory
        let windowController = SubuserAlertWindowController(viewController: controller)
        windowController.delegate = self
        activeWindowControllers.insert(windowController)
        windowController.showWindow(self)
    }
    
    func bringWindowsToForeground() -> Bool {
        guard let mainWindowController = mainWindowController else {
            return false
        }
        
        NSApp.setActivationPolicy(.regular)
        activeWindowControllers.forEach { $0.window?.orderFront(self) }
        mainWindowController.window?.makeKeyAndOrderFront(self)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        return true
    }
        
    func closeWindow(withController controllerType: NSWindowController.Type) {
        activeWindowControllers
            .filter { vc in vc.isKind(of: controllerType) }
            .forEach { vc in
                Task { @MainActor in
                    vc.close()
                }
            }
        activeWindowControllers = activeWindowControllers.filter { vc in
            !vc.isKind(of: controllerType)
        }
    }
    
    func closeActiveWindows(except windowTypesToKeepOpen: [NSWindowController.Type]) {
        let controllersToClose = activeWindowControllers.filter { wc in
            !windowTypesToKeepOpen.contains { type in wc.isKind(of: type) }
        }

        controllersToClose.forEach { $0.close() }
        activeWindowControllers = activeWindowControllers.subtracting(controllersToClose)
    }
    
    func presentKeyModal(viewController: NSViewController) {
        DispatchQueue.main.async { [weak self] in
            guard let parent = self?.mainWindowController?.contentViewController ?? self?.statusMenuWindowController?.contentViewController else {
                return
            }
            self?.replaceOldKeyModal(with: viewController, in: parent)
        }
    }
    
    private func replaceOldKeyModal(with viewController: NSViewController, in parent: NSViewController) {
        closeKeyModalDuplicates(of: viewController, in: parent)
        parent.presentAsModalWindow(viewController)
    }
    
    private func closeKeyModalDuplicates(of viewController: NSViewController, in parent: NSViewController) {
        parent.presentedViewControllers?.forEach { (presented) in
            if presented == viewController {
                parent.dismiss(presented)
            }
        }
    }
    
    func isKeyModalPresent(viewController: NSViewController) -> Bool {
        let parent = mainWindowController?.contentViewController ?? statusMenuWindowController?.contentViewController
        
        guard let presentedViewControllers = parent?.presentedViewControllers else {
            return false
        }
        return presentedViewControllers.contains {
            return type(of: $0) == type(of: viewController)
        }
    }
    
}

extension WindowServiceImplementation: WindowControllerDelegate {
    func windowCloseRequested(_ sender: WindowController) {
        if let mainWindowController = mainWindowController, sender == mainWindowController {
            closeActiveWindows()
            mainWindowController.close()
            NSApp.setActivationPolicy(.accessory)
        } else {
            sender.close()
        }
    }
    
    func windowWillClose(_ sender: WindowController) {
        activeWindowControllers.remove(sender)
    }
}
