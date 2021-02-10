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
import vpncore

protocol WindowServiceFactory {
    func makeWindowService() -> WindowService
}

protocol WindowService: class {

    func setStatusMenuWindowController(_ controller: StatusMenuWindowController)
    
    func showIfPresent<T: NSWindowController>(windowController: T.Type) -> Bool
    func closeIfPresent<T: NSWindowController>(windowController: T.Type)
    
    func showLogin(viewModel: LoginViewModel)
    func showSidebar(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol)
    func showTour()
    
    func openAbout(factory: AboutViewController.Factory)
    func openAcknowledgements()
    func openSettingsWindow(viewModel: SettingsContainerViewModel, tabBarViewModel: SettingsTabBarViewModel)
    func openProfilesWindow(viewModel: ProfilesContainerViewModel)
    func openReportBugWindow(viewModel: ReportBugViewModel, alertService: CoreAlertService)
    
    func bringWindowsToForground() -> Bool
    func closeActiveWindows()
    
    func presentKeyModal(viewController: NSViewController)
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

    private let factory: Factory
    
    private lazy var navService: NavigationService = factory.makeNavigationService()
    
    fileprivate var mainWindowController: WindowController?
    fileprivate var statusMenuWindowController: StatusMenuWindowController?
    fileprivate var activeWindowControllers: [WindowController] = []
    
    fileprivate var tourController: TourController?
    
    init(factory: Factory) {
        self.factory = factory
    }
    
    func setStatusMenuWindowController(_ controller: StatusMenuWindowController) {
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
    }
    
    func showTour() {
        guard let sidebarController = (mainWindowController as? SidebarWindowController)?.contentViewController as? SidebarViewController, let window = mainWindowController?.window else { return }
        if let tourController = tourController {
            tourController.close()
        }
        tourController = TourController(mainWindow: window, sidebarViewController: sidebarController)
    }
    
    func openAbout(factory: AboutViewController.Factory) {
        let controller = AboutViewController()
        controller.factory = factory
        let windowController = AboutWindowController(viewController: controller)
        windowController.delegate = self
        activeWindowControllers.append(windowController)
        windowController.showWindow(self)
    }
    
    func openAcknowledgements() {
        let windowController = AcknowledgementsWindowController(viewController: AcknowledgementsViewController())
        windowController.delegate = self
        activeWindowControllers.append(windowController)
        windowController.showWindow(self)
    }
    
    func openSettingsWindow(viewModel: SettingsContainerViewModel, tabBarViewModel: SettingsTabBarViewModel) {
        NSApp.setActivationPolicy(.regular)
        
        let viewController = SettingsContainerViewController(viewModel: viewModel, tabBarViewModel: tabBarViewModel, factory: factory)
        let windowController = SettingsWindowController(viewController: viewController)
        windowController.delegate = self
        activeWindowControllers.append(windowController)
        windowController.showWindow(self)
    }
    
    func openProfilesWindow(viewModel: ProfilesContainerViewModel) {
        NSApp.setActivationPolicy(.regular)
        
        let viewController = ProfilesContainerViewController(factory: factory, viewModel: viewModel)
        let windowController = ProfilesWindowController(viewController: viewController)
        windowController.delegate = self
        activeWindowControllers.append(windowController)
        windowController.showWindow(self)
    }
    
    func openReportBugWindow(viewModel: ReportBugViewModel, alertService: CoreAlertService) {
        NSApp.setActivationPolicy(.regular)
        
        let viewController = ReportBugViewController(viewModel: viewModel, alertService: alertService)
        let windowController = ReportBugWindowController(viewController: viewController)
        windowController.delegate = self
        activeWindowControllers.append(windowController)
        windowController.showWindow(self)
    }
    
    func bringWindowsToForground() -> Bool {
        guard let mainWindowController = mainWindowController else {
            return false
        }
        
        NSApp.setActivationPolicy(.regular)
        activeWindowControllers.forEach { $0.window?.orderFront(self) }
        mainWindowController.window?.makeKeyAndOrderFront(self)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        return true
    }
    
    func closeActiveWindows() {
        activeWindowControllers.forEach { $0.close() }
        activeWindowControllers = []
    }
    
    func presentKeyModal(viewController: NSViewController) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            if let keyViewController = self.mainWindowController?.contentViewController {
                self.replaceOldKeyModal(with: viewController, in: keyViewController)
            } else if let statusMenu = self.statusMenuWindowController?.contentViewController {
                self.replaceOldKeyModal(with: viewController, in: statusMenu)
            } else {
                return
            }
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
        activeWindowControllers = activeWindowControllers.filter { $0 != sender }
    }
}
