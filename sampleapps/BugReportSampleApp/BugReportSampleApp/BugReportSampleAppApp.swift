//
//  Created on 2022-01-06.
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

import SwiftUI
import BugReport

@main
struct BugReportSampleAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State var isTroubleshootingShown: Bool = false
    @State var isFinished: Bool = false
    
    var body: some View {
        // Prepare the data before using BugReportView
        let delegate = MockDelegate(
            model: model,
            sendCallback: { form, result in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if form.email == "Ok" {
                        result(.success(Void()))
                    } else {
                        result(.failure(NSError(domain: "domain", code: 153, userInfo: [NSLocalizedDescriptionKey: "Just and error"])))
                    }
                }
            }, finishedCallback: {
                self.isFinished = true
                
            }, troubleshootingCallback: {
                self.isTroubleshootingShown = true
                
            })
        
        BugReport.Current.bugReportDelegate = delegate
        return BugReportView()
            .sheet(isPresented: $isFinished) {
                Text("Finished")
            }
            .sheet(isPresented: $isTroubleshootingShown) {
                Text("Troubleshooting screen")
            }
    }
    
    private var model: BugReportModel {
        let bundle = Bundle.main
        guard let testFile1 = bundle.url(forResource: "sample", withExtension: "json") else {
            return BugReportModel(categories: [])
        }
        
        let data = try! Data(contentsOf: testFile1)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom(decapitalizeFirstLetter)
        return try! decoder.decode(BugReportModel.self, from: data)
    }
}

struct MockDelegate: BugReportDelegate {
    var model: BugReportModel
    var prefilledEmail: String = ""
    
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
