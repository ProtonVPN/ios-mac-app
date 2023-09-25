//
//  Created on 10/02/2022.
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

import Modals
import Modals_iOS
import UIKit

class ViewController: UITableViewController {
    
    let upsells: [(type: UpsellType, title: String)] = [
        (.welcomePlus(numberOfServers: 1300, numberOfDevices: 10, numberOfCountries: 61), "Welcome Plus"),
        (.welcomeUnlimited, "Welcome Unlimited"),
        (.welcomeFallback, "Welcome Fallback"),
        (.allCountries(numberOfServers: 1300, numberOfCountries: 61), "All countries"),
        (.country(countryFlag: UIImage(named: "flags_US")!, numberOfDevices: 10, numberOfCountries: 61), "Countries"),
        (.secureCore, "Secure Core"),
        (.netShield, "Net Shield"),
        (.safeMode, "Safe Mode"),
        (.moderateNAT, "Moderate NAT"),
        (.noLogs, "No Logs"),
        (.vpnAccelerator, "VPN Accelerator"),
        (.customization, "Customization"),
        (.profiles, "Profiles"),
        (.cantSkip(before: Date().addingTimeInterval(10), duration: 10, longSkip: false), "Server Roulette"),
        (.cantSkip(before: Date().addingTimeInterval(15), duration: 15, longSkip: true), "Server Roulette (Too many skips)")]
    let upgrades: [(type: UserAccountUpdateViewModel, title: String)] = [
        (.subscriptionDowngradedReconnecting(numberOfCountries: 63,
                                             numberOfDevices: 5,
                                             fromServer: ViewController.fromServer,
                                             toServer: ViewController.toServer), "Subscription Downgraded Reconnecting"),
        (.subscriptionDowngraded(numberOfCountries: 63, numberOfDevices: 5), "Subscription Downgraded"),
        (.reachedDeviceLimit, "Reached Device Limit"),
        (.reachedDevicePlanLimit(planName: "Plus", numberOfDevices: 5), "Reached Device Plan Limit"),
        (.pendingInvoicesReconnecting(fromServer: fromServer, toServer: toServer), "Pending Invoices Reconnecting"),
        (.pendingInvoices, "Pending Invoices")]

    static let fromServer = ("US-CA#63", UIImage(named: "flags_US")!)
    static let toServer = ("US-CA#78", UIImage(named: "flags_US")!)

    let modalsFactory = ModalsFactory()

    override func numberOfSections(in tableView: UITableView) -> Int {
        4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return upsells.count
        case 2:
            return 2
        case 3:
            return upgrades.count
        default:
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ModalTableViewCell", for: indexPath)

        let title: String
        if indexPath.section == 0 {
            title = "What's new"
        } else if indexPath.section == 1 {
            title = upsells[indexPath.row].title
        } else if indexPath.section == 2 {
            if indexPath.row == 0 {
                title = "Discourage Secure Core"
            } else if indexPath.row == 1 {
                title = "Free connections"
            } else {
                title = "-"
            }
        } else if indexPath.section == 3 {
            title = upgrades[indexPath.row].title

        } else {
            title = ""
        }

        if let modalCell = cell as? ModalTableViewCell {
            modalCell.modalTitle.text = title
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewController: UIViewController
        if indexPath.section == 0 {
            viewController = modalsFactory.whatsNewViewController()
        } else if indexPath.section == 1 {
            let modalVC = modalsFactory.upsellViewController(upsellType: upsells[indexPath.row].type)
            modalVC.delegate = self
            viewController = modalVC
        } else if indexPath.section == 2 {
            if indexPath.row == 0 {
                let modalVC = modalsFactory.discourageSecureCoreViewController(
                    onDontShowAgain: nil,
                    onActivate: nil,
                    onCancel: nil,
                    onLearnMore: nil
                )
                viewController = modalVC
            } else if indexPath.row == 1 {
                viewController = modalsFactory.freeConnectionsViewController(
                    countries: [
                        ("Japan", UIImage(named: "flags_JP")),
                        ("Netherlands", UIImage(named: "flags_NL")),
                        ("Romania", UIImage(named: "flags_RO")),
                        ("United States", UIImage(named: "flags_US")),
                        ("Poland", UIImage(named: "flags_PL")),
                    ],
                    upgradeAction: {
                        debugPrint("freeConnectionsViewController")
                    }
                )
            } else {
                fatalError()
            }
        } else if indexPath.section == 3 {
            let modalVC = modalsFactory.userAccountUpdateViewController(viewModel: upgrades[indexPath.row].type,
                                                                        onPrimaryButtonTap: nil)
            viewController = modalVC
        } else {
            fatalError()
        }

        present(viewController, animated: true, completion: nil)
    }
}

extension ViewController: UpsellViewControllerDelegate {
    func userDidTapNext(upsell: UpsellViewController) {
        dismiss(animated: true, completion: nil)
    }

    func shouldDismissUpsell(upsell: UpsellViewController?) -> Bool {
        true
    }

    func userDidRequestPlus(upsell: UpsellViewController?) {
        dismiss(animated: true, completion: nil)
    }
    
    func userDidDismissUpsell(upsell: UpsellViewController?) {
        dismiss(animated: true, completion: nil)
    }

    func upsellDidDisappear(upsell: UpsellViewController?) {

    }
}
