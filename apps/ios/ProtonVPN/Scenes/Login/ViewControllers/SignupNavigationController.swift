//
//  SignupNavigationDelegate.swift
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

import UIKit

class SignupNavigationController: UINavigationController {
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        modalPresentationStyle = .fullScreen
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        modalPresentationStyle = .fullScreen
    }
    
}

extension SignupNavigationController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        var verificationOptionsViewControllerEncountered = false
        navigationController.viewControllers.reversed().forEach { (viewController) in
            removeViewControllerIfNeeded(viewController)
            
            if viewController is HumanVerificationOptionsViewController {
                verificationOptionsViewControllerEncountered = true
            }
        }
        
        /// Leaves only the latest versions of verification-related view controllers, since you can loop through these multiple times
        func removeViewControllerIfNeeded(_ viewController: UIViewController) {
            guard verificationOptionsViewControllerEncountered else { return }
            
            switch viewController {
            case is VerificationCodeViewController, is HumanVerificationOptionsViewController, is VerificationSmsViewController:
                navigationController.viewControllers.removeAll { (iteratedViewController) -> Bool in
                    iteratedViewController === viewController
                }
            default:
                break
            }
        }
    }
}
