//
//  Created on 17/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

final class LokiApiClient {
    let lokiEndpoint = ObfuscatedConstants.lokiDomain + "loki/api/v1/push"
        
    func pushMetrics(id: String, workflow: String, sli: String, metrics: Codable) {
        do {
            if let jsonData = try generateMetricsJson(id: id, workflow: workflow, sli: sli, metricsCodable: metrics) {
                sendToLoki(jsonData)
            } else {
                print("Failed to generate metrics JSON data.")
            }
        } catch {
            print("Error while processing metrics: \(error)")
        }
    }
        
    func sendToLoki(_ jsonData: Data) {
        guard let url = URL(string: lokiEndpoint) else {
            print("Invalid URL")
            return
        }
            
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
            
        let session = URLSession(configuration: .default)
            
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending data to Loki: \(error)")
                return
            }
        }
        task.resume()
    }
        
    func generateMetricsJson(id: String, workflow: String, sli: String, metricsCodable: Codable) throws -> Data? {
        var jsonData: Data? = nil
        do {
            let timestamp = String(Int64(Date().timeIntervalSince1970 * 1_000_000_000))
            let metadata = generateMetadata(id: id)
                    
            let metricsJSONData = try JSONEncoder().encode(metricsCodable)
            let metricsJSONString = String(data: metricsJSONData, encoding: .utf8)!
                    
            let logEntry = LokiPushEntry(streams: [
                LokiStream(stream: generateMetricsLabels(workflow: workflow, sli: sli), values: [
                    [LokiCodable(timestamp), LokiCodable(metricsJSONString), LokiCodable(metadata)]
                ])
            ])
                    
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            jsonData = try encoder.encode(logEntry)
        } catch {
            print("Error generating metrics JSON: \(error)")
        }
            
        return jsonData
    }
        
    func generateMetadata(id: String) -> Metadata {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        guard let protonVpnBundle = getProtonVpnBundle(),
            let appVersion = getAppVersion(bundle: protonVpnBundle),
            let buildId = getBuildId(bundle: protonVpnBundle) else {
            fatalError("Failed to retrieve bundle information.")
        }
        return Metadata(id: id, os_version: versionString, app_version: appVersion, build_id: buildId)
    }
        
    func generateMetricsLabels(workflow: String, sli: String) -> MetricsLabel {
        return MetricsLabel(workflow: workflow, sli: sli, environment: "prod", platform: "IOS", product: "VPN")
    }
        
    private func getBuildId(bundle: Bundle) -> String? {
        return bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
        
    private func getAppVersion(bundle: Bundle) -> String? {
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
        
    private func getProtonVpnBundle() -> Bundle? {
        return Bundle(identifier: "ch.protonmail.vpn")
    }
}
