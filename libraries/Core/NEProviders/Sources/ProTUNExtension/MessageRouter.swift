//
//  Created on 18/02/2026.
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

import Dependencies
import Domain
import Foundation
import NetworkExtension // for updating the provider configuration
import OSLog
import protun

enum MessageRouter {
    typealias Request = ProTUNMessage.Request
    typealias Response = ProTUNMessage.Response

    static func route(_ request: Request, with adapter: ProTUNAdapter) async -> Response {
        guard request.version <= ProTUNMessage.Version.current else {
            return .requestVersionMismatchResponse(from: request.version)
        }
        switch request.payload {
        #if DEBUG
            case .ping:
                return .init(payload: .pong)
        #endif
        case .flushLogsToFile:
            return handleFlushLogsToFile()
        case .retrieveLogsArchive:
            return handleRetrieveLogsArchive()
        case let .pcapRequest(request):
            return await handlePacketCaptureRequest(request, with: adapter)
        case let .pushForkInfo(selector, cookieName, cookieValue):
            return await handlePushSelector(selector, cookieName: cookieName, cookieValue: cookieValue, with: adapter)
        case let .updateConfiguration(update):
            return await handleConfigurationUpdate(update: update, with: adapter)
        case .clearPersistentCache:
            return handleClearPersistentCache()
        case let .ack(errorId):
            return await handleAcknowledgeError(errorId, with: adapter)
        }
    }
}

private extension MessageRouter {
    static func handleFlushLogsToFile() -> Response {
        do {
            let logsURL = try Logger.flushToSingleFile()
            return .init(payload: .logs(.success(logsURL)))
        } catch {
            return .init(payload: .logs(.failure(.init(failureReason: error.localizedDescription))))
        }
    }

    static func handleRetrieveLogsArchive() -> Response {
        do {
            let logsURL = try Logger.retrieveSessionArchive()
            return .init(payload: .logs(.success(logsURL)))
        } catch {
            return .init(payload: .logs(.failure(.init(failureReason: error.localizedDescription))))
        }
    }

    static func handlePacketCaptureRequest(
        _ request: ProTUNMessage.Request.PcapRequest,
        with adapter: ProTUNAdapter
    ) async -> ProTUNMessage.Response {
        switch request {
        case let .start(fileURL):
            await adapter.startPacketCapture(into: fileURL)
        case .stop:
            await adapter.stopPacketCapture()
        }
        return .init(payload: .ack)
    }

    static func handlePushSelector(
        _ selector: String,
        cookieName: String,
        cookieValue: String,
        with adapter: ProTUNAdapter
    ) async -> Response {
        await adapter.handleForkSelector(selector, cookieName: cookieName, cookieValue: cookieValue)
        return .init(payload: .ack)
    }

    static func handleClearPersistentCache() -> Response {
        SecurePersistentCache.clearAllUsers()
        return .init(payload: .ack)
    }

    static func handleAcknowledgeError(_ errorId: UUID, with adapter: ProTUNAdapter) async -> Response {
        await adapter.acknowledgeError(errorId)
        return .init(payload: .ack)
    }

    static func handleConfigurationUpdate(update: ConnectionUpdate, with adapter: ProTUNAdapter) async -> Response {
        // Always ack immediately, confirmation of request will come asynchronously through either the provider
        // configuration dictionary or a `RawChannel`.
        await adapter.enqueueConfigurationUpdate(update)
        return .init(payload: .ack)
    }
}
