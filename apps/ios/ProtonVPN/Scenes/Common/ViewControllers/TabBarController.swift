//
//  TabBarController.swift
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
import vpncore

final class TabBarController: UITabBarController {

    private var quickConnectButtonConnecting = false
    private let quickConnectButton = UIButton()
    private let electron = UIView() // animating ball
    
    var viewModel: TabBarViewModel? {
        didSet {
            viewModel?.delegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        setupView()
        setupQuickConnectView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        viewModel?.stateChanged()
    }

    func setupView() {
        view.backgroundColor = .backgroundColor()
        selectedIndex = 0
        
        tabBar.items?.forEach { item in
            item.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.weakTextColor()], for: .normal)
            item.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.textAccent()], for: .selected)
        }
    }
    
    private func setupQuickConnectView() {
        quickConnectButton.backgroundColor = .clear
        quickConnectButton.layer.masksToBounds = true
        
        quickConnectButton.contentVerticalAlignment = .top
        quickConnectButton.contentHorizontalAlignment = .center
        quickConnectButton.imageView?.contentMode = .scaleAspectFit
        quickConnectButton.adjustsImageWhenHighlighted = false
        
        quickConnectButton.addTarget(self, action: #selector(quickConnectTapped), for: .touchUpInside)
        
        view.addSubview(quickConnectButton)
        
        let bottomItem: Any
        bottomItem = view.safeAreaLayoutGuide
        
        quickConnectButton.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = NSLayoutConstraint(item: quickConnectButton, attribute: .width, relatedBy: .equal, toItem: tabBar, attribute: .width, multiplier: 1 / CGFloat(tabBar.items?.count ?? 5), constant: 4)
        let heightConstraint = NSLayoutConstraint(item: quickConnectButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 66)
        let centerXConstraint = NSLayoutConstraint(item: quickConnectButton, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0)
        let bottomConstraint = NSLayoutConstraint(item: quickConnectButton, attribute: .bottom, relatedBy: .equal, toItem: bottomItem, attribute: .bottom, multiplier: 1, constant: 6)
        view.addConstraints([widthConstraint, heightConstraint, centerXConstraint, bottomConstraint])
        
        // Electron
        electron.backgroundColor = .brandColor()
        electron.isUserInteractionEnabled = false
        quickConnectButton.addSubview(electron)
        
        electron.translatesAutoresizingMaskIntoConstraints = false
        
        disconnectedQuickConnect()
    }
    
    @objc private func quickConnectTapped(_ sender: UIButton) {
        viewModel?.quickConnectTapped()
    }
}

extension TabBarController: TabBarViewModelDelegate {
    func connectedQuickConnect() {
        quickConnectButtonConnecting = false
        self.tabBar.items?[2].setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.weakTextColor()], for: .normal)
        self.tabBar.items?[2].title = LocalizedString.disconnect
        self.quickConnectButton.setImage(UIImage(named: "quick-connect-active-button"), for: .normal)
        UIView.animate(withDuration: 0.25, animations: {
            self.electron.alpha = 0.0
        }, completion: { _ in
            self.electron.layer.removeAllAnimations()
            self.electron.isHidden = true
        })
    }
    
    func connectingQuickConnect() {
        if !quickConnectButtonConnecting { // to avoid animation jumping, don't reset animation during multiple connecting stage calls
            self.tabBar.items?[2].setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.textAccent()], for: .normal)
            self.tabBar.items?[2].title = LocalizedString.connecting
            self.quickConnectButton.setImage(UIImage(named: "quick-connect-connecting-button"), for: .normal)
            self.electron.alpha = 1.0
            self.electron.isHidden = false
            
            // electron points
            let electronPoint1 = CGPoint(x: (self.quickConnectButton.frame.width / 2) - 9, y: (self.quickConnectButton.frame.height / 2) + -10)
            let electronPoint2 = CGPoint(x: (self.quickConnectButton.frame.width / 2) + 2, y: (self.quickConnectButton.frame.height / 2) + 5)
            let electronPoint3 = CGPoint(x: (self.quickConnectButton.frame.width / 2) + 8, y: (self.quickConnectButton.frame.height / 2) + -17)
            let electronWidth1: CGFloat = 12
            let electronWidth2: CGFloat = 4
            let electronWidth3: CGFloat = 8
            
            self.electron.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: electronWidth1, height: electronWidth1))
            self.electron.layer.cornerRadius = electronWidth1 / 2
            self.electron.center = electronPoint1
            
            let options = UIView.KeyframeAnimationOptions([UIView.KeyframeAnimationOptions.repeat, UIView.KeyframeAnimationOptions.calculationModeLinear])
            UIView.animateKeyframes(withDuration: 2.2, delay: 0, options: options, animations: {
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.3, animations: {
                    self.electron.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: electronWidth2, height: electronWidth2))
                    self.electron.layer.cornerRadius = electronWidth2 / 2
                    self.electron.center = electronPoint2
                })
                UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.4, animations: {
                    self.electron.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: electronWidth3, height: electronWidth3))
                    self.electron.layer.cornerRadius = electronWidth3 / 2
                    self.electron.center = electronPoint3
                })
                UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3, animations: {
                    self.electron.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: electronWidth1, height: electronWidth1))
                    self.electron.layer.cornerRadius = electronWidth1 / 2
                    self.electron.center = electronPoint1
                })
            }, completion: nil)
        }
        
        quickConnectButtonConnecting = true
    }
    
    func disconnectedQuickConnect() {
        quickConnectButtonConnecting = false
        guard self.tabBar.items?.count > 2 else { return }
        self.tabBar.items?[2].setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.weakTextColor()], for: .normal)
        self.tabBar.items?[2].title = LocalizedString.quickConnect
        self.quickConnectButton.setImage(UIImage(named: "quick-connect-inactive-button"), for: .normal)
        self.electron.isHidden = true
        self.electron.layer.removeAllAnimations()
    }
}

extension TabBarController: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // to help with data updating and easier to understand navigation, pop nvc to root
        if let navigationViewController = viewController as? UINavigationController, navigationViewController != self.selectedViewController {
            navigationViewController.popToRootViewController(animated: false)
        }
        
        if viewController is ProtonQCViewController {
            return false
        } else if let viewModel = viewModel, viewController == viewControllers?.last { // settings
            return viewModel.settingShouldBeSelected()
        } else {
            return true
        }
    }
}
