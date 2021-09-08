//
//  EnvironmentsViewController.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import UIKit
import vpncore

protocol EnvironmentsViewControllerDelegate: AnyObject {
    func userDidSelectContinue()
}

final class EnvironmentsViewController: UIViewController {

    @IBOutlet private weak var environmentLabel: UILabel!
    @IBOutlet private weak var customEnvironmentTextField: UITextField!

    weak var delegate: EnvironmentsViewControllerDelegate?
    var propertiesManager: PropertiesManagerProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Endpoint"
        environmentLabel.text = propertiesManager.apiEndpoint ?? ApiConstants.doh.liveURL
        customEnvironmentTextField.delegate = self
    }

    @IBAction func resetTapped(_ sender: Any) {
        propertiesManager.apiEndpoint = nil
        showAlert(environment: ApiConstants.doh.liveURL)
    }

    @IBAction func changeTapped(_ sender: Any) {
        guard let text = customEnvironmentTextField.text, !text.isEmpty else {
            return
        }

        propertiesManager.apiEndpoint = text
        showAlert(environment: text)
    }

    @IBAction func continueTapped(_ sender: Any) {
        delegate?.userDidSelectContinue()
    }

    private func showAlert(environment: String) {
        let alert = UIAlertController(title: "Environment changed", message: "Environment has been changed to \(environment)\n\nYou need to KILL THE APP and start it again for the change to take effect.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
}

extension EnvironmentsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        _ = textField.resignFirstResponder()
        return true
    }
}
