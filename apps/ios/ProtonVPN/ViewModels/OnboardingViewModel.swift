//
//  OnboardingViewModel.swift
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

class OnboardingViewModel: NSObject {
    
    typealias Factory = LoginServiceFactory & PropertiesManagerFactory
    
    let pageViewController: OnboardingPageViewController
    let pages: [UIViewController]
    
    var configureUiForIndex: (() -> Void)?
    
    private let loginService: LoginService
    private let propertiesManager: PropertiesManagerProtocol
    
    private lazy var endpoints = [ApiConstants.liveURL] + ObfuscatedConstants.internalUrls
    
    private var currentPageIndex: Int {
        guard let currentPage = pageViewController.viewControllers?.first,
              let currentIndex = pages.firstIndex(of: currentPage) else {
            return 0
        }
        
        return currentIndex
    }
    
    private var onLastPage: Bool {
        return currentPageIndex == pages.count - 1
    }
    
    private var currentPage: UIViewController? {
        return pageViewController.viewControllers?.first
    }
    
    init(pageViewController: OnboardingPageViewController, factory: Factory) {
        self.pageViewController = pageViewController
        
        self.loginService = factory.makeLoginService()
        self.propertiesManager = factory.makePropertiesManager()
        
        pages = [
            OnboardingContentViewController(viewModel: OnboardingContentViewModel(image: UIImage(named: "onboarding1"), title: LocalizedString.iosOnboardingPage1Title, description: LocalizedString.iosOnboardingPage1Description)),
            OnboardingContentViewController(viewModel: OnboardingContentViewModel(image: UIImage(named: "onboarding2"), title: LocalizedString.iosOnboardingPage2Title, description: LocalizedString.iosOnboardingPage2Description)),
            OnboardingContentViewController(viewModel: OnboardingContentViewModel(image: UIImage(named: "onboarding3"), title: LocalizedString.iosOnboardingPage3Title, description: LocalizedString.iosOnboardingPage3Description))
        ]
        
        super.init()
        
        pageViewController.delegate = self
        pageViewController.dataSource = self
        
        pageViewController.setViewControllers([pages[0]], direction: .forward, animated: false, completion: nil)
    }
    
    func hideNextButton() -> Bool {
        return onLastPage
    }
    
    func hideAuthenticationButtons() -> Bool {
        return !onLastPage
    }
    
    func secondaryButtonTitle() -> String {
        return onLastPage ? LocalizedString.discoverTheApp : LocalizedString.skip
    }
    
    func secondaryButtonAccessibilityId() -> String {
        return onLastPage ? "Discover the app" : "Skip"
    }
    
    func next() {
        guard !onLastPage,
              let currentPage = currentPage,
              let newPage = pageViewController(pageViewController, viewControllerAfter: currentPage) else { return }
        
        pageViewController.setViewControllers([newPage], direction: .forward, animated: true) { [weak self] finished in
            guard let `self` = self else { return }
            
            self.pageViewController(self.pageViewController, didFinishAnimating: finished, previousViewControllers: [currentPage], transitionCompleted: finished)
        }
    }
    
    func performSecondaryAction() {
        if onLastPage {
            loginService.presentMainInterface()
        } else {
            guard let currentPage = currentPage,
                  let lastPage = pages.last else { return }
            
            pageViewController.setViewControllers([lastPage], direction: .forward, animated: false) { [weak self] finished in
                guard let `self` = self else { return }
                
                self.pageViewController(self.pageViewController, didFinishAnimating: finished, previousViewControllers: [currentPage], transitionCompleted: finished)
            }
        }
    }
    
    func signUp() {
        loginService.presentSignup(dismissible: true)
    }
    
    func logIn() {
        loginService.presentLogin(dismissible: true)
    }
}

extension OnboardingViewModel: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        configureUiForIndex?()
    }
}

extension OnboardingViewModel: UIPageViewControllerDataSource {
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return pages.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return currentPageIndex
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = pages.firstIndex(of: viewController), currentIndex > 0 else { return nil }
        
        return pages[pages.index(before: currentIndex)]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard !onLastPage else { return nil }
        
        return pages[pages.index(after: currentPageIndex)]
    }
}

// MARK: - Enpoint picker
extension OnboardingViewModel: UIPickerViewDelegate, UIPickerViewDataSource {
    
    private(set) var endpoint: String {
        get {
            return ApiConstants.baseURL
        }
        set {
            propertiesManager.apiEndpoint = newValue
        }
    }
    
    // MARK: - UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return endpoints[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        endpoint = endpoints[row]
    }
    
    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return endpoints.count
    }
}
