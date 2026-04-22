//
//  Created on 26/03/2026.
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

extension IPCNotifications.Channel {
    enum Error: Swift.Error {
        case inconsistentRead
    }
}

public extension IPCNotifications {
    final class Channel<Payload: Codable> {
        let buffer: SharedBuffer
        let notification: Notification

        private let encoder: PropertyListEncoder
        private let decoder: PropertyListDecoder

        public init(notification: Notification, fileURL: URL) throws {
            self.buffer = try .init(url: fileURL)
            self.notification = notification
            self.encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            self.decoder = PropertyListDecoder()
        }
    }
}

extension IPCNotifications.Channel {
    // We're boxing values cause PropertyListEncoder/Decoder can have issues with raw objects
    private struct Box<T: Codable>: Codable {
        let value: T
    }
}

public extension IPCNotifications.Channel {
    /// Encodes `payload` into the shared buffer and fires the Darwin
    /// notification so the reader wakes immediately.
    func post(_ payload: Payload) throws {
        let data = try encoder.encode(Box(value: payload))
        let seqNumber = try buffer.write(data)
        IPCNotifications.postRawState(notification, state: seqNumber)
    }
}

public extension IPCNotifications.Channel {
    @discardableResult
    func observe(
        includingCurrentValue: Bool = false,
        handler: @MainActor @escaping (Result<Payload, any Swift.Error>) -> Void
    ) -> IPCNotifications.Token {
        observe(on: .main, includingCurrentValue: includingCurrentValue) { result in
            MainActor.assumeIsolated { handler(result) }
        }
    }

    @discardableResult
    func observe(
        on queue: DispatchQueue,
        includingCurrentValue: Bool = false,
        handler: @escaping (Result<Payload, any Swift.Error>) -> Void
    ) -> IPCNotifications.Token {
        let token = IPCNotifications.observeRawState(notification, queue: queue) { sequence in
            guard let data = self.buffer.read(expectedSequence: sequence) else {
                handler(.failure(Error.inconsistentRead)); return
            }
            do {
                let payload = try self.decoder.decode(Box<Payload>.self, from: data)
                handler(.success(payload.value))
            } catch {
                handler(.failure(error))
            }
        }

        if includingCurrentValue {
            let writeCount = buffer.currentWriteCount
            if writeCount > 0, let data = buffer.read(expectedSequence: writeCount) {
                do {
                    let payload = try decoder.decode(Box<Payload>.self, from: data)
                    queue.async {
                        handler(.success(payload.value))
                    }
                } catch {
                    queue.async {
                        handler(.failure(error))
                    }
                }
            }
        }

        return token
    }

    func stream(includingCurrentValue: Bool = false) -> AsyncStream<Payload> {
        AsyncStream { continuation in
            let token = observe(includingCurrentValue: includingCurrentValue) { payload in
                if let successPayload = try? payload.get() {
                    continuation.yield(successPayload)
                }
            }
            let box = IPCNotifications.TokenBox(token)
            continuation.onTermination = { _ in box.token = nil }
        }
    }
}
