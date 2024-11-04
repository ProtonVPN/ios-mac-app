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
    private lazy var updateURL: URL? = {
        guard let identifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(identifier)") else {
            return nil
        }

        return url
    }()

    private lazy var currentVersion: String? = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }()

    enum UpdateCheckCodingKeys: String, CodingKey {
        case results
        case version
        case minimumOsVersion
    }

    enum UpdateCheckError: String, Error, CustomStringConvertible, CustomNSError {
        static let errorDomain = "UpdateCheckErrorDomain"

        case missingPlistKeys = "Missing info in Info.plist"
        case noDataReturned = "No data returned"
        case dataReturnedWasNotValidJSON = "Data returned was not valid JSON"
        case noResultsFoundInJSON = "No results found in JSON"
        case noVersionFoundInJSON = "No version found in JSON"
        case noMinimumOSVersionFoundInJSON = "No minimum OS version found in JSON"
        case unrecognizedMinimumOSVersion = "Unrecognized minimum OS version"

        var description: String { rawValue }

        var errorUserInfo: [String : Any] {
            [NSLocalizedDescriptionKey: description]
        }

        var errorCode: Int {
            switch self {
            case .missingPlistKeys: return 1000
            case .noDataReturned: return 1001
            case .noVersionFoundInJSON: return 1002
            case .noMinimumOSVersionFoundInJSON: return 1003
            case .noResultsFoundInJSON: return 1004
            case .dataReturnedWasNotValidJSON: return 1005
            case .unrecognizedMinimumOSVersion: return 1006
            }
        }
    }

    private func fetchInfoFromAppStore(_ callback: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let updateURL else {
            executeOnUIThread {
                callback(.failure(UpdateCheckError.missingPlistKeys))
            }
            return
        }

        let session = URLSession(
            configuration: URLSessionConfiguration.default,
            delegate: nil,
            delegateQueue: OperationQueue.main
        )

        let task = session.dataTask(with: updateURL) { (data, response, error) in
            let result: Result<[String: Any], Error>
            defer {
                executeOnUIThread {
                    callback(result)
                }
            }

            if let error {
                result = .failure(error)
                return
            }

            guard let data else {
                result = .failure(UpdateCheckError.noDataReturned)
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] else {
                    throw UpdateCheckError.dataReturnedWasNotValidJSON
                }

                guard let results = json[UpdateCheckCodingKeys.results.stringValue] as? [Any],
                      let firstResult = results.first as? [String: Any] else {
                    throw UpdateCheckError.noResultsFoundInJSON
                }

                result = .success(firstResult)
            } catch {
                result = .failure(error)
            }
        }
        task.resume()
    }

    private func fetchInfoFromAppStore() async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { cont in
            fetchInfoFromAppStore { result in
                cont.resume(with: result)
            }
        }
    }

    func minimumVersionRequiredByNextUpdate() async -> OperatingSystemVersion {
        log.debug("Start checking if minimum system version required by next update", category: .appUpdate)

        do {
            let appInfo = try await fetchInfoFromAppStore()

            guard let minimumOSVersionString = appInfo[UpdateCheckCodingKeys.minimumOsVersion.stringValue] as? String else {
                throw UpdateCheckError.noMinimumOSVersionFoundInJSON
            }

            guard let minimumOSVersion = OperatingSystemVersion(osVersionString: minimumOSVersionString) else {
                throw UpdateCheckError.unrecognizedMinimumOSVersion
            }

            return minimumOSVersion
        } catch {
            log.error("Couldn't check minimum version required by next update", metadata: ["error": "\(error)"])
            return ProcessInfo.processInfo.operatingSystemVersion
        }
    }

    func isUpdateAvailable() async -> Bool {
        log.debug("Start checking if app update is available on the AppStore", category: .appUpdate)

        do {
            let appInfo = try await fetchInfoFromAppStore()
            guard let currentVersion = currentVersion,
                  let appStoreVersion = appInfo[UpdateCheckCodingKeys.version.stringValue] as? String else {
                throw UpdateCheckError.noVersionFoundInJSON
            }

            log.debug("Checking if app update is available",
                      category: .appUpdate, metadata: ["current": "\(currentVersion)", "appStore": "\(appStoreVersion)"])
            return appStoreVersion.compareVersion(to: currentVersion) == .orderedDescending
        } catch {
            log.error("Error while checking for an update",
                      category: .appUpdate, event: .error, metadata: ["error": "\(error)"])
            return false
        }
    }
    
    func startUpdate() {
        guard let infoPlist = Bundle.main.infoDictionary, let identifier = infoPlist["AppStoreID"] as? String else {
            return
        }
        SafariService().open(url: "itms-apps://itunes.apple.com/app/id\(identifier)?mt=8")
    }
}
