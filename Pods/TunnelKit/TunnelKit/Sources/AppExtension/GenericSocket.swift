//
//  GenericSocket.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 4/16/18.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation

/// Receives events from a `GenericSocket`.
public protocol GenericSocketDelegate: class {

    /**
     The socket timed out.
     **/
    func socketDidTimeout(_ socket: GenericSocket)

    /**
     The socket became active.
     **/
    func socketDidBecomeActive(_ socket: GenericSocket)

    /**
     The socket shut down.
     
     - Parameter failure: `true` if the shutdown was caused by a failure.
     **/
    func socket(_ socket: GenericSocket, didShutdownWithFailure failure: Bool)

    /**
     The socket has a better path.
     **/
    func socketHasBetterPath(_ socket: GenericSocket)
}

/// An opaque socket implementation.
public protocol GenericSocket {

    /// The address of the remote endpoint.
    var remoteAddress: String? { get }
    
    /// `true` if the socket has a better path.
    var hasBetterPath: Bool { get }
    
    /// `true` if the socket was shut down.
    var isShutdown: Bool { get }

    /// The optional delegate for events.
    var delegate: GenericSocketDelegate? { get set }

    /**
     Observes socket events.

     - Parameter queue: The queue to observe events in.
     - Parameter activeTimeout: The timeout in milliseconds for socket activity.
     **/
    func observe(queue: DispatchQueue, activeTimeout: Int)

    /**
     Stops observing socket events.
     **/
    func unobserve()

    /**
     Shuts down the socket
     **/
    func shutdown()
    
    /**
     Returns an upgraded socket if available (e.g. when a better path exists).
 
     - Returns: An upgraded socket if any.
     **/
    func upgraded() -> GenericSocket?
}
