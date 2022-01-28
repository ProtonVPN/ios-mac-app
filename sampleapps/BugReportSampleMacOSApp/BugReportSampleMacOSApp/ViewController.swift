//
//  Created on 2022-01-27.
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

import Cocoa
import BugReport

class ViewController: NSViewController {
    
    private var bugReportDelegate: BugReportDelegate?
    @IBOutlet private var statusTextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        statusTextField.setAccessibilityIdentifier("statusLabel")

        bugReportDelegate = MockDelegate(
            model: model,
            sendCallback: { form, result in
                self.statusTextField.stringValue = "Sent"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if form.email == "success@email.com" {
                        result(.success(Void()))
                    } else {
                        result(.failure(NSError(domain: "domain", code: 153, userInfo: [NSLocalizedDescriptionKey: "Just and error"])))
                    }
                }
            }, finishedCallback: {
                print("finishedCallback")
                self.statusTextField.stringValue = "Finished"
                
            }, troubleshootingCallback: {
                print("troubleshootingCallback")
                self.statusTextField.stringValue = "Troubleshooting"
            })
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
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

    @IBAction func buttonClicked(_ sender: Any) {
        let bugReportCreator = MacOSBugReportCreator()
        guard let viewController = bugReportCreator.createBugReportViewController(delegate: bugReportDelegate!, colors: nil) else {
            return
        }
        let windowController = ReportBugWindowController(viewController: viewController)
        windowController.showWindow(self)
    }

}

class MockDelegate: BugReportDelegate {
    var model: BugReportModel
    var prefilledEmail: String = ""
    
    public init(model: BugReportModel, sendCallback: ((BugReportResult, @escaping (SendReportResult) -> Void) -> Void)?, finishedCallback: (() -> Void)?, troubleshootingCallback: (() -> Void)?) {
        self.model = model
        self.sendCallback = sendCallback
        self.finishedCallback = finishedCallback
        self.troubleshootingCallback = troubleshootingCallback
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
}
