//
//  Threading.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2021 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

public func executeOnUIThread(closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

/// Utility function for bridging completion handler functions with separate success and failure callbacks, with async,
/// throwing functions.
public func executeOnUIThread<T>(
    _ closure: @escaping () async throws -> T,
    success: @escaping (T) -> Void,
    failure: @escaping (Error) -> Void
) {
    Task { @MainActor in
        do {
            success(try await closure())
        } catch {
            failure(error)
        }
    }
}

public func dispatchAssert(condition: DispatchPredicate) {
    #if DEBUG
    dispatchPrecondition(condition: condition)
    #endif
}

/// Allow multiple readers concurrent access to a value, and allow thread-safe barrier writes to this value using
/// dispatch_barrier_sync on a per-instance queue.
public class ConcurrentReaders<T> {
    private var value: T

    /// Concurrent queue for accessing the value.
    private let queue: DispatchQueue

    /// Schedule a synchronous operation on the queue and return the value.
    private var sync: ((() -> T) -> T)!

    /// Schedule a synchronous operation on the queue, inserting a barrier before and after the operation.
    private var syncBarrier: ((() -> Void) -> Void)!

    /// Schedule an asynchronous operation on the queue, inserting a barrier before and after the operation.
    private var asyncBarrier: ((@escaping () -> Void) -> Void)!

    public init(_ value: T, queue: DispatchQueue? = nil) {
        self.value = value
        let label = "ch.protonvpn.rwsync.\(String(describing: T.self)).\(UUID().uuidString)"
        self.queue = queue ?? DispatchQueue(label: label, attributes: .concurrent)

        self.sync = { [unowned self] in
            self.queue.sync(execute: $0)
        }

        self.syncBarrier = { [unowned self] in
            self.queue.sync(flags: .barrier, execute: $0)
        }

        self.asyncBarrier = { [unowned self] in
            self.queue.async(flags: .barrier, execute: $0)
        }
    }

    public func get() -> T {
        sync { value }
    }

    public func update(_ closure: @escaping ((inout T) -> Void)) {
        syncBarrier { closure(&value) }
    }

    public func updateAsync(_ closure: @escaping ((inout T) -> Void)) {
        asyncBarrier { [unowned self] in closure(&self.value) }
    }

    public func unsafeUpdateNoSync(_ closure: @escaping ((inout T) -> Void)) {
        closure(&self.value)
    }
}

@propertyWrapper
public class ConcurrentlyReadable<T> {
    private var _wrappedValue: ConcurrentReaders<T>

    public var wrappedValue: T {
        get {
            _wrappedValue.get()
        }
        set {
            _wrappedValue.update {
                $0 = newValue
            }
        }
    }

    public func updateAsync(_ closure: @escaping ((inout T) -> Void)) {
        _wrappedValue.updateAsync(closure)
    }

    public func unsafeUpdateNoSync(_ closure: @escaping ((inout T) -> Void)) {
        _wrappedValue.unsafeUpdateNoSync(closure)
    }

    public init(wrappedValue: T, queue: DispatchQueue? = nil) {
        self._wrappedValue = ConcurrentReaders(wrappedValue, queue: queue)
    }
}
