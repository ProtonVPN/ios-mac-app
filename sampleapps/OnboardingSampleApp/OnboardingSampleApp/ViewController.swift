//
//  Created on 03.01.2022.
//
//  Copyright (c) 2022 Proton AG
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

import UIKit
import Onboarding

final class ViewController: UIViewController {
    private var coordinator: OnboardingCoordinator!

    @IBAction private func startATapped(_ sender: Any) {
        startOnboarding(variant: .A)
    }

    @IBAction private func startBTapped(_ sender: Any) {
        startOnboarding(variant: .B)
    }

    private func startOnboarding(variant: OnboardingVariant) {
        coordinator = OnboardingCoordinator(configuration: Configuration(variant: variant, colors: Colors(background: .black, text: .white, brand: UIColor(red: 77/255, green: 163/255, blue: 88/255, alpha: 1), weakText: UIColor(red: 156/255, green: 160/255, blue: 170/255, alpha: 1), activeBrandButton: UIColor(red: 133/255, green: 181/255, blue: 121/255, alpha: 1), secondaryBackground: UIColor(red: 37/255, green: 39/255, blue: 44/255, alpha: 1))))
        coordinator.delegate = self
        let vc = coordinator.start()
        present(vc, animated: true, completion: nil)
    }
}

extension ViewController: OnboardingCoordinatorDelegate {
    func userDidRequestPlanPurchase(completion: @escaping OnboardingPlanPurchaseCompletion) {
        let planPurchaseViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PlanPurchase") as! PlanPurchaseViewController
        planPurchaseViewController.completion = completion

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion(.planPurchaseViewControllerReady(planPurchaseViewController))
        }
    }

    func userDidRequestConnection(completion: @escaping OnboardingConnectionRequestCompletion) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completion(Country(name: "United States", flag: UIImage(named: "Flag")!))
        }
    }

    func onboardingCoordinatorDidFinish(requiresConnection: Bool) {
        coordinator = nil
        dismiss(animated: true, completion: nil)
    }
}
