//
//  Created on 2022-02-07.
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

import Foundation
import Ergonomics
import LegacyCommon

final class iOSUpdateManager: UpdateChecker {
    
    func isUpdateAvailable(_ callback: @escaping (Bool) -> Void) {
        log.debug("Start checking if app update is available on the AppStore", category: .appUpdate)
        
        guard let infoPlist = Bundle.main.infoDictionary,
              let currentVersion = infoPlist["CFBundleShortVersionString"] as? String,
              let identifier = infoPlist["CFBundleIdentifier"] as? String,
              let url = URL(string: "http://itunes.apple.com/lookup?bundleId=\(identifier)") else {
                  log.error("Error while checking for an update", category: .appUpdate, event: .error, metadata: ["error": "Wrong app setup. Missing info in Info.plist"])
                  executeOnUIThread {
                      callback(false)
                  }
                  return
              }

        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: OperationQueue.main)

        let task = session.dataTask(with: url) { (data, response, error) in
            do {
                if let error = error {
                    throw error
                }
                guard let data = data else {
                    throw NSError(domain: nil, code: 1001, localizedDescription: "No data returned")
                }
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any]
                guard let result = (json?["results"] as? [Any])?.first as? [String: Any], let appStoreVersion = result["version"] as? String else {
                    throw NSError(domain: nil, code: 1001, localizedDescription: "No version found in JSON")
                }

                log.debug("Checking if app update is available", category: .appUpdate, metadata: ["current": "\(currentVersion)", "appStore": "\(appStoreVersion)"])
                callback(appStoreVersion.compareVersion(to: currentVersion) == .orderedDescending)
                
            } catch {
                log.error("Error while checking for an update", category: .appUpdate, event: .error, metadata: ["error": "\(error)"])
                callback(false)
                return
            }
        }
        task.resume()
        
    }
    
    func startUpdate() {
        guard let infoPlist = Bundle.main.infoDictionary, let identifier = infoPlist["AppStoreID"] as? String else {
            return
        }
        SafariService().open(url: "itms-apps://itunes.apple.com/app/id\(identifier)?mt=8")
    }

}
