//
//  WindowService.swift
//  ProtonVPN - Created on 01.07.19.
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

import Foundation
import UIKit
import GSMessages

protocol WindowServiceFactory {
    func makeWindowService() -> WindowService
}

protocol WindowService: AnyObject {
    func show(viewController: UIViewController)
    func addToStack(_ controller: UIViewController, checkForDuplicates: Bool)
    func popStackToRoot()
    
    func present(modal: UIViewController)
    func dismissModal(_ completion: (() -> Void)?)

    func present(message: String, type: PresentedMessageType, accessibilityIdentifier: String?)
}

/// GSMessageType wrapper
enum PresentedMessageType {
    case error
    case success
    
    var gsMessageType: GSMessageType {
        switch self {
        case .error: return GSMessageType.error
        case .success: return GSMessageType.success
        }
    }
}

final class WindowServiceImplementation: WindowService {

    private let window: UIWindow

    var rootViewControllerObserver: NSKeyValueObservation?

    /// This array was introduced when working on the one-time notification modal. We want to present the modal as soon as the app starts.
    /// First problem was that we try to present it before we actually have a `rootViewController`, so we need to wait for it to be assigned, thus the `rootViewControllerObserver` was created.
    /// Second problem is that the `rootViewController` is assigned twice in quick succession and we only want to show the modal on the last one.
    /// We decided to try to show it on each of the `rootViewController`s but only "approve" it when it actually finishes showing the modal.
    var scheduledViewControllers: [UIViewController] = []

    init (window: UIWindow) {
        self.window = window

        if ProcessInfo.processInfo.arguments.contains("UITests") {
            window.layer.speed = 100
        }
        observeRootViewController(window)
        setupAppearance()
    }

    private func observeRootViewController(_ window: UIWindow) {
        rootViewControllerObserver = window.observe(\.rootViewController) { [weak self] _, _ in
            self?.presentScheduledViewControllers()
        }
    }

    private func presentScheduledViewControllers() {
        var viewControllers = scheduledViewControllers
        guard let modal = viewControllers.popLast() else { return }
        topmostPresentedViewController?.present(modal, animated: true) { [weak self] in
            _ = self?.scheduledViewControllers.popLast()
            self?.presentScheduledViewControllers()
        }
    }
    
    func setupAppearance() {
#if !REDESIGN
        window.tintColor = .brandColor()
        
        UINavigationBar.appearance().barTintColor = .backgroundColor()
        UINavigationBar.appearance().tintColor = .normalTextColor()
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.normalTextColor()]
        UINavigationBar.appearance().isTranslucent = false
        
        UITabBar.appearance().backgroundColor = .secondaryBackgroundColor()
        UITabBar.appearance().barTintColor = .secondaryBackgroundColor()
        UITabBar.appearance().tintColor = .iconAccent()
        UITabBar.appearance().unselectedItemTintColor = .iconWeak()
        UITabBar.appearance().isTranslucent = false

        UISwitch.appearance().onTintColor = .brandColor()
        
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.textAccent()], for: .selected)
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.weakTextColor()], for: .normal)
        
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.secondaryBackgroundColor()
        UIPageControl.appearance().currentPageIndicatorTintColor = .brandColor()
        
        GSMessage.successBackgroundColor = UIColor.brandColor()
        GSMessage.warningBackgroundColor = UIColor.notificationWarningColor()
        GSMessage.errorBackgroundColor = UIColor.notificationErrorColor()        
        
        UITableView.appearance().sectionHeaderTopPadding = 0.0
#endif
    }
    
    // MARK: - Presentation
    
    func show(viewController: UIViewController) {
        window.rootViewController = viewController
        window.makeKeyAndVisible()
    }
    
    func addToStack(_ controller: UIViewController, checkForDuplicates: Bool = false) {
        guard let navigationController = topMostNavigationController() else {
            return
        }
        
        guard checkForDuplicates else {
            navigationController.pushViewController(controller, animated: true)
            return
        }
        
        for existingController in navigationController.viewControllers {
            if object_getClassName(controller) == object_getClassName(existingController) {
                navigationController.popToViewController(existingController, animated: true)
                return // Don't add two controllers of the same class
            }
        }
        
        navigationController.pushViewController(controller, animated: true)
    }
    
    func popStackToRoot() {
        let navigationController = topMostNavigationController()
        navigationController?.popToRootViewController(animated: true)
    }

    // MARK: - Modal presentation
    
    func present(modal: UIViewController) {
        guard let presentingViewController = topmostPresentedViewController else {
            scheduledViewControllers.append(modal)
            return
        }
        presentingViewController.present(modal, animated: true, completion: nil)
    }
    
    func dismissModal(_ completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if let rootViewController = self.window.rootViewController {
                if let topViewController = rootViewController.presentedViewController {
                    topViewController.dismiss(animated: true, completion: completion)
                } else {
                    rootViewController.dismiss(animated: true, completion: completion)
                }
            }
        }
    }
    
    // MARK: - Alerts

    func present(message: String, type: PresentedMessageType, accessibilityIdentifier: String?) {
        let options = accessibilityIdentifier != nil ? UIConstants.messageOptions + [.accessibilityIdentifier(accessibilityIdentifier!)] : UIConstants.messageOptions
        topmostPresentedViewController?.showMessage(message, type: type.gsMessageType, options: options)
    }
    
    // MARK: - Private functions

    private var topmostPresentedViewController: UIViewController? {
        guard let rootViewController = window.rootViewController else { return nil }
        var controller = rootViewController
        while let childController = controller.presentedViewController {
            controller = childController
        }
        return controller
    }
    
    private func topMostNavigationController() -> UINavigationController? {
        guard let rootViewController = window.rootViewController else { return nil }
        var navigationController: UINavigationController?
        if let topViewController = rootViewController.presentedViewController as? UINavigationController {
            navigationController = topViewController
        } else if let tabBarController = rootViewController as? TabBarController, let topViewController = tabBarController.selectedViewController as? UINavigationController {
            navigationController = topViewController
        } else {
            navigationController = rootViewController as? UINavigationController
        }
        
        // Search for modally presented controllers
        if navigationController == nil {
            var controller = rootViewController
            while let modal = controller.presentedViewController {
                controller = modal
            }
            navigationController = controller as? UINavigationController
        }
        
        while let modal = navigationController?.presentedViewController as? UINavigationController {
            navigationController = modal
        }
        return navigationController
    }
}
