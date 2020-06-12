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

protocol WindowService: class {

    func show(viewController: UIViewController)
    func addToStack(_ controller: UIViewController)
    func popStackToRoot()
    var navigationStackAvailable: Bool { get }
    
    func present(modal: UIViewController)
    func replace(with modal: UIViewController)
    func dismissModal()
    
    func present(alert: UIAlertController)
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

class WindowServiceImplementation: WindowService {
    
    private let window: UIWindow
    
    init (window: UIWindow) {
        self.window = window
        
        setupAppearance()
    }
    
    func setupAppearance() {
        window.tintColor = .protonGreen()
        
        UINavigationBar.appearance().barTintColor = .protonLightGrey()
        UINavigationBar.appearance().tintColor = .protonWhite()
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.protonWhite()]
        UINavigationBar.appearance().isTranslucent = false
        
        UITabBar.appearance().backgroundColor = .protonGreen()
        UITabBar.appearance().barTintColor = .protonLightGrey()
        UITabBar.appearance().tintColor = .protonWhite()
        UITabBar.appearance().isTranslucent = false
        
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.protonWhite()], for: .selected)
        UITabBarItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.protonUnavailableGrey()], for: .normal)
        
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.protonLightGrey()
        UIPageControl.appearance().currentPageIndicatorTintColor = .protonGreen()
        
        GSMessage.successBackgroundColor = UIColor.protonGreen()
        GSMessage.warningBackgroundColor = UIColor.protonYellow()
        GSMessage.errorBackgroundColor = UIColor.protonRed()
    }
    
    // MARK: - Presentation
    
    func show(viewController: UIViewController) {
        window.rootViewController = viewController
        window.makeKeyAndVisible()
    }
    
    func addToStack(_ controller: UIViewController) {
        let navigationController = topMostNavigationController()
        navigationController?.pushViewController(controller, animated: true)
    }
    
    func popStackToRoot() {
        let navigationController = topMostNavigationController()
        navigationController?.popToRootViewController(animated: true)
    }
    
    var navigationStackAvailable: Bool {
        return topMostNavigationController() != nil
    }
    
    // MARK: - Modal presentation
    
    func present(modal: UIViewController) {
        topmostPresentedViewController?.present(modal, animated: true, completion: nil)
    }
    
    func dismissModal() {
        DispatchQueue.main.async {
            if let rootViewController = self.window.rootViewController {
                if let topViewController = rootViewController.presentedViewController {
                    topViewController.dismiss(animated: true)
                } else {
                    rootViewController.dismiss(animated: true)
                }
            }
        }
    }
    
    func replace(with modal: UIViewController) {
        if let rootViewController = window.rootViewController {
            if let topViewController = rootViewController.presentedViewController {
                let hider = LogoWithMapView.loadViewFromNib() as LogoWithMapView
                hider.backgroundColor = .protonBlack()
                rootViewController.view.addFillingSubview(hider)
                
                topViewController.dismiss(animated: true) {
                    rootViewController.present(modal, animated: true) {
                        hider.removeFromSuperview()
                    }
                }
            } else {
                rootViewController.present(modal, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Alerts
    
    func present(alert: UIAlertController) {
        presentAlertFromAppropriateViewController(alert: alert)
    }
    
    func present(message: String, type: PresentedMessageType, accessibilityIdentifier: String?) {
        let options = accessibilityIdentifier != nil ? UIConstants.messageOptions + [.accessibilityIdentifier(accessibilityIdentifier!)] : UIConstants.messageOptions
        topmostPresentedViewController?.showMessage(message, type: type.gsMessageType, options: options)
    }
    
    // MARK: - Private functions
    
    private func presentAlertFromAppropriateViewController(alert: UIAlertController) {
        topmostPresentedViewController?.present(alert, animated: true, completion: nil)
    }
    
    private var topmostPresentedViewController: UIViewController? {
        guard let rootViewController = window.rootViewController else {
            return nil
        }
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
        } else {
            navigationController = rootViewController as? UINavigationController
        }
        
        while let modal = navigationController?.presentedViewController as? UINavigationController {
            navigationController = modal
        }
        return navigationController
    }
}
