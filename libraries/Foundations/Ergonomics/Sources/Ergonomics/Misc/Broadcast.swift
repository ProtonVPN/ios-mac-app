//
//  Created on 18/08/2026.
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

/// A stream and its sending side kept together, fanned out to any number of subscriber streams.
public struct Broadcast<Element: Sendable>: Sendable {
    private let continuation: AsyncStream<Element>.Continuation
    private let source: StreamSource<Element>

    public init() {
        let (stream, continuation) = AsyncStream<Element>.makeStream()
        self.continuation = continuation
        self.source = .source(for: stream)
    }

    public func send(_ element: Element) {
        continuation.yield(element)
    }

    /// A stream of the elements sent from now on.
    public func subscribe() -> AsyncStream<Element> {
        source.newStream
    }
}

public extension Broadcast where Element == Void {
    /// Wakes every current subscriber.
    func send() {
        send(())
    }
}
