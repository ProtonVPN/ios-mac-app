//
//  Created on 19/05/2026.
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

#if os(iOS) && DEBUG
    import Domain
    import Foundation
    import IPCErgonomics

    struct PcapStateStore {
        private let defaults: UserDefaults
        private let encoder = JSONEncoder()
        private let decoder = JSONDecoder()

        init(defaults: UserDefaults = .domainUserDefaults) {
            self.defaults = defaults
        }

        var current: CaptureSession {
            get {
                guard let session = try? defaults.captureSession(with: decoder) else {
                    return .noSession
                }
                return session
            }
            nonmutating set {
                do {
                    try defaults.store(newValue, with: encoder)
                    IPCNotifications.post(.pcapSessionChanged)
                } catch {}
            }
        }

        @discardableResult
        func mutate(_ transform: (inout CaptureSession) -> Void) -> Bool {
            var next = current
            let before = next
            transform(&next)
            guard next != before else { return false }
            current = next
            return true
        }

        func observe(_ handler: @escaping @MainActor (CaptureSession) -> Void) {
            IPCNotifications.observe(.pcapSessionChanged) {
                handler(current)
            }
        }
    }

    private extension UserDefaults {
        func captureSession(with decoder: JSONDecoder) throws -> CaptureSession? {
            guard let data = data(forKey: CaptureSession.storageKey) else {
                return nil
            }
            return try decoder.decode(CaptureSession.self, from: data)
        }

        func store(_ session: CaptureSession, with encoder: JSONEncoder) throws {
            let data = try encoder.encode(session)
            set(data, forKey: CaptureSession.storageKey)
        }
    }
#endif
