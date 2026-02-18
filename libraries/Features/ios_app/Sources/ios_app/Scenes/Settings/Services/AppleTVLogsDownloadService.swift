//
//  Created on 12/02/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Network

final class AppleTVLogsDownloadService {
    private enum Constants {
        static let logsPath = "/download"
        static let bonjourType = "_protonvpnlogs._tcp"
        static let bonjourName = "ProtonVPN-AppleTV-Logs"
        static let bonjourDomain = "local"
        static let timeoutSeconds = 15
        static let destinationFilename = "ProtonVPN_AppleTV.log"
    }

    private let discoveryQueue = DispatchQueue(label: "ch.protonvpn.logs.discovery")
    private var browser: NWBrowser?
    private var resolutionConnection: NWConnection?
    private var discoveryTimeoutWorkItem: DispatchWorkItem?
    private var completion: ((Result<URL, Error>) -> Void)?

    func downloadLogs(completion: @escaping (Result<URL, Error>) -> Void) {
        cancel()
        self.completion = completion

        let browser = NWBrowser(
            for: .bonjour(type: Constants.bonjourType, domain: Constants.bonjourDomain),
            using: .tcp
        )
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case let .failed(error) = state {
                finish(with: .failure(error))
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            guard let endpoint = matchingServiceEndpoint(from: results) else { return }
            discoveryTimeoutWorkItem?.cancel()
            resolveServiceEndpointAndDownload(endpoint)
        }

        browser.start(queue: discoveryQueue)

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finish(with: .failure(AppleTVLogsDownloadError.discoveryTimedOut))
        }
        discoveryTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Constants.timeoutSeconds), execute: timeoutWorkItem)
    }

    func cancel() {
        discoveryTimeoutWorkItem?.cancel()
        discoveryTimeoutWorkItem = nil
        browser?.cancel()
        browser = nil
        resolutionConnection?.cancel()
        resolutionConnection = nil
        completion = nil
    }

    private func matchingServiceEndpoint(from results: Set<NWBrowser.Result>) -> NWEndpoint? {
        for result in results {
            guard case let .service(name: name, type: type, domain: domain, interface: _) = result.endpoint else {
                continue
            }
            guard normalizedBonjourValue(name) == normalizedBonjourValue(Constants.bonjourName) else {
                continue
            }
            guard normalizedBonjourValue(type) == normalizedBonjourValue(Constants.bonjourType) else {
                continue
            }
            guard normalizedBonjourValue(domain) == normalizedBonjourValue(Constants.bonjourDomain) else {
                continue
            }
            return result.endpoint
        }
        return nil
    }

    private func normalizedBonjourValue(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
    }

    private func resolveServiceEndpointAndDownload(_ endpoint: NWEndpoint) {
        browser?.cancel()
        browser = nil

        resolutionConnection?.cancel()
        let connection = NWConnection(to: endpoint, using: .tcp)
        resolutionConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                guard
                    let remoteEndpoint = resolutionConnection?.currentPath?.remoteEndpoint,
                    case let .hostPort(host: host, port: port) = remoteEndpoint,
                    let downloadURL = makeDownloadURL(host: host, port: port)
                else {
                    resolutionConnection?.cancel()
                    resolutionConnection = nil
                    finish(with: .failure(AppleTVLogsDownloadError.invalidResolvedEndpoint))
                    return
                }
                resolutionConnection?.cancel()
                resolutionConnection = nil
                downloadLogs(from: downloadURL)

            case let .failed(error):
                resolutionConnection?.cancel()
                resolutionConnection = nil
                finish(with: .failure(error))

            default:
                break
            }
        }

        connection.start(queue: discoveryQueue)
    }

    private func makeDownloadURL(host: NWEndpoint.Host, port: NWEndpoint.Port) -> URL? {
        let portValue = Int(port.rawValue)
        switch host {
        case let .name(name, _):
            var components = URLComponents()
            components.scheme = "http"
            components.host = name.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            components.port = portValue
            components.path = Constants.logsPath
            return components.url
        case let .ipv4(address):
            var components = URLComponents()
            components.scheme = "http"
            components.host = address.debugDescription
            components.port = portValue
            components.path = Constants.logsPath
            return components.url
        case let .ipv6(address):
            let rawIPv6 = address.debugDescription
            let encodedIPv6: String
            let elements = rawIPv6.split(separator: "%")
            switch elements.count {
            case 2:
                encodedIPv6 = "\(elements[0])%25\(elements[1])"
            default:
                encodedIPv6 = rawIPv6
            }
            return URL(string: "http://[\(encodedIPv6)]:\(portValue)\(Constants.logsPath)")
        @unknown default:
            return nil
        }
    }

    private func downloadLogs(from downloadURL: URL) {
        let task = URLSession.shared.downloadTask(with: downloadURL) { [weak self] temporaryURL, _, error in
            guard let self else { return }

            if let error {
                finish(with: .failure(error))
                return
            }

            guard let temporaryURL else {
                finish(with: .failure(AppleTVLogsDownloadError.emptyDownloadedFile))
                return
            }

            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(Constants.destinationFilename)
            try? FileManager.default.removeItem(at: destinationURL)

            do {
                try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
                finish(with: .success(destinationURL))
            } catch {
                finish(with: .failure(error))
            }
        }
        task.resume()
    }

    private func finish(with result: Result<URL, Error>) {
        discoveryTimeoutWorkItem?.cancel()
        discoveryTimeoutWorkItem = nil
        browser?.cancel()
        browser = nil
        resolutionConnection?.cancel()
        resolutionConnection = nil

        let completion = completion
        self.completion = nil
        DispatchQueue.main.async {
            completion?(result)
        }
    }
}

private enum AppleTVLogsDownloadError: LocalizedError {
    case discoveryTimedOut
    case invalidResolvedEndpoint
    case emptyDownloadedFile

    var errorDescription: String? {
        switch self {
        case .discoveryTimedOut:
            "Could not find Apple TV logs service on local network."
        case .invalidResolvedEndpoint:
            "Resolved service has no valid host or port."
        case .emptyDownloadedFile:
            "No file was downloaded."
        }
    }
}
