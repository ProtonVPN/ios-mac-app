//
//  Created on 2022-01-18.
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
import BugReport

class ViewController: UIViewController {
    
    @IBOutlet private var updateSwitch: UISwitch!
    @IBOutlet private var statusLabel: UILabel!
    
    private var bugReportDelegate: MockBugReportDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        bugReportDelegate = MockBugReportDelegate(
            model: model,
            sendCallback: { form, result in
                DispatchQueue.main.async {
                    self.statusLabel.text = "Sent"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if form.email == "success@email.com" {
                            result(.success(Void()))
                        } else {
                            result(.failure(NSError(domain: "domain", code: 153, userInfo: [NSLocalizedDescriptionKey: "Just an error"])))
                        }
                    }
                }
            }, finishedCallback: {
                DispatchQueue.main.async {
                    print("finishedCallback")
                    self.statusLabel.text = "Finished"
                    self.dismiss(animated: true, completion: nil)
                }
                
            }, troubleshootingCallback: {
                DispatchQueue.main.async {
                    print("troubleshootingCallback")
                    self.statusLabel.text = "Troubleshooting"
                    self.dismiss(animated: true, completion: nil)
                }
            }, updateAppCallback: {
                DispatchQueue.main.async {
                    print("updateAppCallback")
                    self.updateSwitch.isOn = false
                    self.updateSwitchChanged()
                    self.statusLabel.text = "Update"
                }
            })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction private func updateSwitchChanged() {
        bugReportDelegate?.updateAvailable = updateSwitch.isOn
    }

    @IBAction private func openBugReport() {
        let bugReportCreator = iOSBugReportCreator()
        if let viewController = bugReportCreator.createBugReportViewController(delegate: bugReportDelegate!, colors: Colors.testColors) {
            self.present(viewController, animated: true, completion: nil)
        }
    }
    
    private var model: BugReportModel {
        let bundle = Bundle.main
        guard let testFile1 = bundle.url(forResource: "sample", withExtension: "json") else {
            return BugReportModel()
        }
        
        let data = try! Data(contentsOf: testFile1)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom(decapitalizeFirstLetter)
        return try! decoder.decode(BugReportModel.self, from: data)
    }

}

class MockBugReportDelegate: BugReportDelegate {
    
    var model: BugReportModel
    var prefilledEmail: String = ""
    var prefilledUsername: String = ""
    
    public init(model: BugReportModel, sendCallback: ((BugReportResult, @escaping (SendReportResult) -> Void) -> Void)?, finishedCallback: (() -> Void)?, troubleshootingCallback: (() -> Void)?, updateAppCallback: (() -> Void)?) {
        self.model = model
        self.sendCallback = sendCallback
        self.finishedCallback = finishedCallback
        self.troubleshootingCallback = troubleshootingCallback
        self.updateAppCallback = updateAppCallback
    }
    
    var sendCallback: ((BugReportResult, @escaping (SendReportResult) -> Void) -> Void)?
    
    func send(form: BugReportResult, result: @escaping (SendReportResult) -> Void) {
        sendCallback?(form, result)
    }
    
    var finishedCallback: (() -> Void)?
    
    func finished() {
        finishedCallback?()
    }
    
    var troubleshootingCallback: (() -> Void)?
    
    func troubleshootingRequired() {
        troubleshootingCallback?()
    }
    
    var updateAvailable: Bool = true {
        didSet {
            updateAvailabilityChanged?(updateAvailable)
        }
    }

    var updateAppCallback: (() -> Void)?
    
    func updateApp() {
        updateAppCallback?()
    }
    
    func checkUpdateAvailability() {
        updateAvailabilityChanged?(updateAvailable)
    }
    
    var updateAvailabilityChanged: ((Bool) -> Void)?
}
