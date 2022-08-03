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
        (.allCountries(numberOfDevices: 10, numberOfServers: 1300, numberOfCountries: 61), "All countries"),
        (.secureCore, "Secure Core"),
        (.netShield, "Net Shield"),
        (.safeMode, "Safe Mode"),
        (.moderateNAT, "Moderate NAT"),
        (.noLogs, "No Logs")]
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

    static let fromServer = UserAccountUpdateViewModel.Server(name: "US-CA#63", flag: UIImage(named: "Flag")!)
    static let toServer = UserAccountUpdateViewModel.Server(name: "US-CA#78", flag: UIImage(named: "Flag")!)

    let modalsFactory = ModalsFactory(colors: Colors())

    override func numberOfSections(in tableView: UITableView) -> Int {
        4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return upsells.count
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
            title = upsells[indexPath.row].title
        } else if indexPath.section == 1 {
            title = "Discourage Secure Core"
        } else if indexPath.section == 2 {
            title = "New Brand"
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
            let modalVC = modalsFactory.upsellViewController(upsellType: upsells[indexPath.row].type)
            modalVC.delegate = self
            viewController = modalVC
        } else if indexPath.section == 1 {
            let modalVC = modalsFactory.discourageSecureCoreViewController(onDontShowAgain: nil,
                                                                           onActivate: nil,
                                                                           onCancel: nil,
                                                                           onLearnMore: nil)
            viewController = modalVC
        } else if indexPath.section == 2 {
            let modalVC = modalsFactory.newBrandViewController(icons: ModalIcons(), onDismiss: nil, onReadMore: nil)
            modalVC.modalPresentationStyle = .overFullScreen
            viewController = modalVC
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
    func userDidTapNext() {
        dismiss(animated: true, completion: nil)
    }

    func shouldDismissUpsell() -> Bool {
        true
    }

    func userDidRequestPlus() {
        dismiss(animated: true, completion: nil)
    }
    
    func userDidDismissUpsell() {
        dismiss(animated: true, completion: nil)
    }
}

struct Colors: ModalsColors {
    var background: UIColor
    var secondaryBackground: UIColor
    var text: UIColor
    var textAccent: UIColor
    var brand: UIColor
    var weakText: UIColor
    var weakInteraction: UIColor

    init() {
        background = UIColor(red: 0.11, green: 0.106, blue: 0.141, alpha: 1)
        secondaryBackground = UIColor(red: 37/255, green: 39/255, blue: 44/255, alpha: 1)
        text = .white
        textAccent = UIColor(red: 138 / 255, green: 110 / 255, blue: 255 / 255, alpha: 1)
        brand = UIColor(red: 0.427451, green: 0.290196, blue: 1, alpha: 1)
        weakText = UIColor(red: 0.654902, green: 0.643137, blue: 0.709804, alpha: 1)
        weakInteraction = UIColor(red: 59 / 255, green: 55 / 255, blue: 71 / 255, alpha: 1)
    }
}

struct ModalIcons: NewBrandIcons {
    let vpnMain: Image
    let driveMain: Image
    let calendarMain: Image
    let mailMain: Image

    init() {
        vpnMain = UIImage(named: "VPNMain")!
        driveMain = UIImage(named: "DriveMain")!
        calendarMain = UIImage(named: "CalendarMain")!
        mailMain = UIImage(named: "MailMain")!
    }
}
