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
    @IBOutlet private weak var startAButton: UIButton!
    @IBOutlet private weak var vpnSuccessSwitch: UISwitch!
    @IBOutlet private weak var startBButton: UIButton!

    private var coordinator: OnboardingCoordinator!

    override func viewDidLoad() {
        super.viewDidLoad()

        vpnSuccessSwitch.accessibilityIdentifier = "VPNSuccessSwitch"
        startAButton.accessibilityIdentifier = "StartButton"
    }

    @IBAction private func startATapped(_ sender: Any) {
        startOnboarding()
    }

    private func startOnboarding() {
        coordinator = OnboardingCoordinator(configuration: Configuration(constants: Constants(numberOfDevices: 10,
                                                                                              numberOfServers: 1300,
                                                                                              numberOfFreeServers: 23,
                                                                                              numberOfFreeCountries: 3,
                                                                                              numberOfCountries: 61),
                                                                         telemetryEnabled: true))
        coordinator.delegate = self
        let vc = coordinator.start()
        present(vc, animated: true, completion: nil)
    }
}

extension ViewController: OnboardingCoordinatorDelegate {
    func preferenceChangeUsageData(telemetryUsageData: Bool) {

    }

    func preferenceChangeCrashReports(telemetryCrashReports: Bool) {

    }

    func userDidRequestPlanPurchase(completion: @escaping OnboardingPlanPurchaseCompletion) {
        let planPurchaseViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PlanPurchase") as! PlanPurchaseViewController
        planPurchaseViewController.completion = completion

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion(.planPurchaseViewControllerReady(planPurchaseViewController))
        }
    }

    func userDidRequestConnection(completion: @escaping OnboardingConnectionRequestCompletion) {
        let succes = vpnSuccessSwitch.isOn

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if succes {
                completion(Country(name: "United States", flag: UIImage(named: "Flag")!))
            } else {
                completion(nil)
            }
        }
    }

    func onboardingCoordinatorDidFinish(requiresConnection: Bool) {
        coordinator = nil
        dismiss(animated: true, completion: nil)
    }
}
