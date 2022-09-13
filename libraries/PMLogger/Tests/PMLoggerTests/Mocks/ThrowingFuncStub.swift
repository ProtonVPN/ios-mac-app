//
//  ThrowingFuncStub.swift
//  ProtonCore-TestingToolkit - Created on 13/09/2021.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

// IMPORTANT:
// This is a mix of several files copied from ProtonCore-TestingToolkit.
// Atm this library is available only via CocoaPods. Please delete this file and
// import the library properly, when it is available through SPM.

import XCTest

@propertyWrapper
public final class ThrowingFuncStub<Input, Output, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12> {

    public var wrappedValue: ThrowingStubbedFunction<Input, Output, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12>

    init(initialReturn: @escaping (Input) throws -> Output, function: String, line: UInt, file: String) {
        wrappedValue = ThrowingStubbedFunction(initialReturn: .init(initialReturn), function: function, line: line, file: file)
    }

    init(initialReturn: InitialReturn<Input, Output>, function: String, line: UInt, file: String) {
        wrappedValue = ThrowingStubbedFunction(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    init(function: String, line: UInt, file: String) where Output == Void {
        wrappedValue = ThrowingStubbedFunction(initialReturn: .init { _ in }, function: function, line: line, file: file)
    }
}

public final class ThrowingStubbedFunction<Input, Output, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12> {

    public private(set) var callCounter: UInt = .zero
    public private(set) var capturedArguments: [CapturedArguments<Input, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12>] = []

    public var description: String
    public var ensureWasCalled = false
    public var failOnBeingCalledUnexpectedly = false

    private lazy var implementation: (UInt, Input) throws -> Output = { [unowned self] _, input in
        guard let initialReturn = initialReturn else {
            XCTFail("initial return was not provided: \(self.description)")
            fatalError()
        }
        if self.failOnBeingCalledUnexpectedly {
            XCTFail("this method should not be called but was: \(self.description)")
            return try initialReturn.closure(input)
        }
        return try initialReturn.closure(input)
    }

    private var initialReturn: InitialReturn<Input, Output>?

    init(initialReturn: InitialReturn<Input, Output>, function: String, line: UInt, file: String) {
        self.initialReturn = initialReturn
        description = "\(function) at line \(line) of file \(file)"
    }

    func replaceBody(_ newImplementation: @escaping (UInt, Input) throws -> Output) {
        initialReturn = nil
        implementation = newImplementation
    }

    func appendBody(_ additionalImplementation: @escaping (UInt, Input) throws -> Output) {
        guard initialReturn == nil else {
            replaceBody(additionalImplementation)
            return
        }
        let currentImplementation = implementation
        implementation = {
            // ignoring the first output
            _ = try currentImplementation($0, $1)
            return try additionalImplementation($0, $1)
        }
    }

    func callAsFunction(input: Input, arguments: CapturedArguments<Input, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12>) throws -> Output {
        callCounter += 1
        capturedArguments.append(arguments)
        return try implementation(callCounter, input)
    }

    deinit {
        if ensureWasCalled && callCounter == 0 {
            XCTFail("this method should be called but wasn't: \(description)")
        }
    }
}

public enum Absent: Int, Equatable, Codable { case nothing }

public struct InitialReturn<Input, Output> {
    let closure: (Input) throws -> Output

    init(_ closure: @escaping (Input) throws -> Output) {
        self.closure = closure
    }

    public static var crash: InitialReturn<Input, Output> {
        .init { _ in
            fatalError("Stub setup error — you must provide a default value of type \(Output.self) if this stub is ever called!")
        }
    }
}

public struct CapturedArguments<Input, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12> {

    private let argument1: A1
    private let argument2: A2
    private let argument3: A3
    private let argument4: A4
    private let argument5: A5
    private let argument6: A6
    private let argument7: A7
    private let argument8: A8
    private let argument9: A9
    private let argument10: A10
    private let argument11: A11
    private let argument12: A12

    private init(a1: A1, a2: A2, a3: A3, a4: A4, a5: A5, a6: A6, a7: A7, a8: A8, a9: A9, a10: A10, a11: A11, a12: A12) {
        self.argument1 = a1
        self.argument2 = a2
        self.argument3 = a3
        self.argument4 = a4
        self.argument5 = a5
        self.argument6 = a6
        self.argument7 = a7
        self.argument8 = a8
        self.argument9 = a9
        self.argument10 = a10
        self.argument11 = a11
        self.argument12 = a12
    }
}

extension CapturedArguments: Equatable where A1: Equatable, A2: Equatable, A3: Equatable, A4: Equatable, A5: Equatable, A6: Equatable,
                                             A7: Equatable, A8: Equatable, A9: Equatable, A10: Equatable, A11: Equatable, A12: Equatable {}

extension CapturedArguments: Codable where A1: Codable, A2: Codable, A3: Codable, A4: Codable, A5: Codable, A6: Codable,
                                           A7: Codable, A8: Codable, A9: Codable, A10: Codable, A11: Codable, A12: Codable {}

extension CapturedArguments where Input == Void, A1 == Absent, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                  A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    init(input _: Input) {
        self.init(a1: .nothing, a2: .nothing, a3: .nothing, a4: .nothing, a5: .nothing, a6: .nothing,
                  a7: .nothing, a8: .nothing, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == A1, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                  A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }

    public var value: A1 { a1 }

    init(input: Input) {
        self.init(a1: input, a2: .nothing, a3: .nothing, a4: .nothing, a5: .nothing, a6: .nothing,
                  a7: .nothing, a8: .nothing, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2), A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                  A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }

    public var first: A1 { a1 }
    public var second: A2 { a2 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: .nothing, a4: .nothing, a5: .nothing, a6: .nothing,
                  a7: .nothing, a8: .nothing, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3), A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                  A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }

    public var first: A1 { a1 }
    public var second: A2 { a2 }
    public var third: A3 { a3 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: .nothing, a5: .nothing, a6: .nothing,
                  a7: .nothing, a8: .nothing, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4), A5 == Absent, A6 == Absent, A7 == Absent,
                                  A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }

    public var first: A1 { a1 }
    public var second: A2 { a2 }
    public var third: A3 { a3 }
    public var forth: A4 { a4 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: .nothing, a6: .nothing,
                  a7: .nothing, a8: .nothing, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4, A5), A6 == Absent, A7 == Absent,
                                  A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }
    public var a5: A5 { argument5 }

    public var first: A1 { a1 }
    public var last: A5 { a5 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: input.4, a6: .nothing,
                  a7: .nothing, a8: .nothing, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4, A5, A6), A7 == Absent,
                                  A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }
    public var a5: A5 { argument5 }
    public var a6: A6 { argument6 }

    public var first: A1 { a1 }
    public var last: A6 { a6 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: input.4, a6: input.5,
                  a7: .nothing, a8: .nothing, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4, A5, A6, A7),
                                  A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }
    public var a5: A5 { argument5 }
    public var a6: A6 { argument6 }
    public var a7: A7 { argument7 }

    public var first: A1 { a1 }
    public var last: A7 { a7 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: input.4, a6: input.5,
                  a7: input.6, a8: .nothing, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4, A5, A6, A7, A8), A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }
    public var a5: A5 { argument5 }
    public var a6: A6 { argument6 }
    public var a7: A7 { argument7 }
    public var a8: A8 { argument8 }

    public var first: A1 { a1 }
    public var last: A8 { a8 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: input.4, a6: input.5,
                  a7: input.6, a8: input.7, a9: .nothing, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9), A10 == Absent, A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }
    public var a5: A5 { argument5 }
    public var a6: A6 { argument6 }
    public var a7: A7 { argument7 }
    public var a8: A8 { argument8 }
    public var a9: A9 { argument9 }

    public var first: A1 { a1 }
    public var last: A9 { a9 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: input.4, a6: input.5,
                  a7: input.6, a8: input.7, a9: input.8, a10: .nothing, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10), A11 == Absent, A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }
    public var a5: A5 { argument5 }
    public var a6: A6 { argument6 }
    public var a7: A7 { argument7 }
    public var a8: A8 { argument8 }
    public var a9: A9 { argument9 }
    public var a10: A10 { argument10 }

    public var first: A1 { a1 }
    public var last: A10 { a10 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: input.4, a6: input.5,
                  a7: input.6, a8: input.7, a9: input.8, a10: input.9, a11: .nothing, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11), A12 == Absent {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }
    public var a5: A5 { argument5 }
    public var a6: A6 { argument6 }
    public var a7: A7 { argument7 }
    public var a8: A8 { argument8 }
    public var a9: A9 { argument9 }
    public var a10: A10 { argument10 }
    public var a11: A11 { argument11 }

    public var first: A1 { a1 }
    public var last: A11 { a11 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: input.4, a6: input.5,
                  a7: input.6, a8: input.7, a9: input.8, a10: input.9, a11: input.10, a12: .nothing)
    }
}

extension CapturedArguments where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) {

    public var a1: A1 { argument1 }
    public var a2: A2 { argument2 }
    public var a3: A3 { argument3 }
    public var a4: A4 { argument4 }
    public var a5: A5 { argument5 }
    public var a6: A6 { argument6 }
    public var a7: A7 { argument7 }
    public var a8: A8 { argument8 }
    public var a9: A9 { argument9 }
    public var a10: A10 { argument10 }
    public var a11: A11 { argument11 }
    public var a12: A12 { argument12 }

    public var first: A1 { a1 }
    public var last: A12 { a12 }

    init(input: Input) {
        self.init(a1: input.0, a2: input.1, a3: input.2, a4: input.3, a5: input.4, a6: input.5,
                  a7: input.6, a8: input.7, a9: input.8, a10: input.9, a11: input.10, a12: input.11)
    }
}

extension ThrowingFuncStub where Input == Void, Output == Void, A1 == Absent, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: (T) -> () throws -> Void,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == Void, A1 == Absent, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: (T) -> () throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> () throws -> Output,
                               initialReturn: @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> () throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == A1, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: (T) -> (A1) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2), A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3), A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4), A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4, A5), A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4, A5, A6), A7 == Absent, A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4, A5, A6, A7), A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8), A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9), A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10), A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11), A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingFuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) throws -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) throws -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) throws -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension ThrowingStubbedFunction where Input == Void, A1 == Absent, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt) throws -> Output) {
        replaceBody { counter, _ in try implementation(counter) }
    }

    public func addToBody(_ implementation: @escaping (UInt) throws -> Output) {
        appendBody { counter, _ in try implementation(counter) }
    }

    public func callAsFunction() throws -> Output {
        let input: Void = ()
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == A1, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1) throws -> Output) {
        replaceBody { try implementation($0, $1) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1) throws -> Output) {
        appendBody { try implementation($0, $1) }
    }

    public func callAsFunction(_ a1: A1) throws -> Output {
        let input = a1
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2), A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2) throws -> Output {
        let input = (a1, a2)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3), A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3) throws -> Output {
        let input = (a1, a2, a3)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4), A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4) throws -> Output {
        let input = (a1, a2, a3, a4)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4, A5), A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5) throws -> Output {
        let input = (a1, a2, a3, a4, a5)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4, A5, A6),
                                A7 == Absent, A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6) throws -> Output {
        let input = (a1, a2, a3, a4, a5, a6)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7),
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7) throws -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8), A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8) throws -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9), A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8, _ a9: A9) throws -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8, a9)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10), A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9) }
    }

    public func callAsFunction(
        _ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8, _ a9: A9, _ a10: A10
    ) throws -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11), A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10) }
    }

    public func callAsFunction(
        _ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8, _ a9: A9, _ a10: A10, _ a11: A11
    ) throws -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension ThrowingStubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) throws -> Output) {
        replaceBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10, $1.11) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) throws -> Output) {
        appendBody { try implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10, $1.11) }
    }

    public func callAsFunction(
        _ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8, _ a9: A9, _ a10: A10, _ a11: A11, _ a12: A12
    ) throws -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12)
        return try callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

@propertyWrapper
public final class FuncStub<Input, Output, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12> {

    public var wrappedValue: StubbedFunction<Input, Output, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12>

    init(initialReturn: @escaping (Input) throws -> Output, function: String, line: UInt, file: String) {
        wrappedValue = StubbedFunction(initialReturn: .init(initialReturn), function: function, line: line, file: file)
    }

    init(initialReturn: InitialReturn<Input, Output>, function: String, line: UInt, file: String) {
        wrappedValue = StubbedFunction(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    init(function: String, line: UInt, file: String) where Output == Void {
        wrappedValue = StubbedFunction(initialReturn: .init { _ in }, function: function, line: line, file: file)
    }
}

public final class StubbedFunction<Input, Output, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12> {

    public private(set) var callCounter: UInt = .zero
    public var capturedArguments: [CapturedArguments<Input, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12>] {
        capturedArgumentsStorage.value
    }
    
    private var capturedArgumentsStorage: Atomic<[CapturedArguments<Input, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12>]> = .init([])

    public var description: String
    public var ensureWasCalled = false
    public var failOnBeingCalledUnexpectedly = false

    private lazy var implementation: (UInt, Input) -> Output = { [unowned self] _, input in
        guard let initialReturn = initialReturn else {
            XCTFail("initial return was not provided: \(self.description)")
            fatalError()
        }
        if self.failOnBeingCalledUnexpectedly {
            XCTFail("this method should not be called but was: \(self.description)")
            return try! initialReturn.closure(input)
        }
        return try! initialReturn.closure(input)
    }

    private var initialReturn: InitialReturn<Input, Output>?

    init(initialReturn: InitialReturn<Input, Output>, function: String, line: UInt, file: String) {
        self.initialReturn = initialReturn
        description = "\(function) at line \(line) of file \(file)"
    }

    func replaceBody(_ newImplementation: @escaping (UInt, Input) -> Output) {
        initialReturn = nil
        implementation = newImplementation
    }

    func appendBody(_ additionalImplementation: @escaping (UInt, Input) -> Output) {
        guard initialReturn == nil else {
            replaceBody(additionalImplementation)
            return
        }
        let currentImplementation = implementation
        implementation = {
            // ignoring the first output
            _ = currentImplementation($0, $1)
            return additionalImplementation($0, $1)
        }
    }

    func callAsFunction(input: Input, arguments: CapturedArguments<Input, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12>) -> Output {
        callCounter += 1
        capturedArgumentsStorage.mutate { $0.append(arguments) }
        return implementation(callCounter, input)
    }

    deinit {
        if ensureWasCalled && callCounter == 0 {
            XCTFail("this method should be called but wasn't: \(description)")
        }
    }
}

extension FuncStub where Input == Void, A1 == Absent, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: (T) -> () -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> () -> Output,
                               initialReturn: @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> () -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> () -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == A1, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: (T) -> (A1) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2), A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3), A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4), A5 == Absent, A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4, A5), A6 == Absent, A7 == Absent,
                         A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4, A5, A6), A7 == Absent, A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4, A5, A6, A7), A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8), A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9), A10 == Absent, A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10), A11 == Absent, A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11), A12 == Absent {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension FuncStub where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) {

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) -> Output,
                               initialReturn: @autoclosure @escaping () throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: { _ in try initialReturn() }, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) -> Output,
                               initialReturn: @escaping (Input) throws -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: @escaping (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) -> Output,
                               initialReturn: InitialReturn<Input, Output>,
                               function: String = #function, line: UInt = #line, file: String = #filePath) {
        self.init(initialReturn: initialReturn, function: function, line: line, file: file)
    }

    public convenience init<T>(_ prototype: (T) -> (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) -> Output,
                               function: String = #function, line: UInt = #line, file: String = #filePath) where Output == Void {
        self.init(function: function, line: line, file: file)
    }
}

extension StubbedFunction where Input == Void, A1 == Absent, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt) -> Output) {
        replaceBody { counter, _ in implementation(counter) }
    }

    public func addToBody(_ implementation: @escaping (UInt) -> Output) {
        appendBody { counter, _ in implementation(counter) }
    }

    public func callAsFunction() -> Output {
        let input: Void = ()
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == A1, A2 == Absent, A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1) -> Output) {
        replaceBody { implementation($0, $1) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1) -> Output) {
        appendBody { implementation($0, $1) }
    }

    public func callAsFunction(_ a1: A1) -> Output {
        let input = a1
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2), A3 == Absent, A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2) -> Output) {
        appendBody { implementation($0, $1.0, $1.1) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2) -> Output {
        let input = (a1, a2)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3), A4 == Absent, A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3) -> Output {
        let input = (a1, a2, a3)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4), A5 == Absent, A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4) -> Output {
        let input = (a1, a2, a3, a4)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4, A5), A6 == Absent, A7 == Absent,
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5) -> Output {
        let input = (a1, a2, a3, a4, a5)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4, A5, A6),
                                A7 == Absent, A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6) -> Output {
        let input = (a1, a2, a3, a4, a5, a6)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7),
                                A8 == Absent, A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7) -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8), A9 == Absent, A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8) -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9), A10 == Absent, A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8, _ a9: A9) -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8, a9)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10), A11 == Absent, A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9) }
    }

    public func callAsFunction(_ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8, _ a9: A9, _ a10: A10) -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11), A12 == Absent {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10) }
    }

    public func callAsFunction(
        _ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8, _ a9: A9, _ a10: A10, _ a11: A11
    ) -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

extension StubbedFunction where Input == (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) {

    public func bodyIs(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) -> Output) {
        replaceBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10, $1.11) }
    }

    public func addToBody(_ implementation: @escaping (UInt, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) -> Output) {
        appendBody { implementation($0, $1.0, $1.1, $1.2, $1.3, $1.4, $1.5, $1.6, $1.7, $1.8, $1.9, $1.10, $1.11) }
    }

    public func callAsFunction(
        _ a1: A1, _ a2: A2, _ a3: A3, _ a4: A4, _ a5: A5, _ a6: A6, _ a7: A7, _ a8: A8, _ a9: A9, _ a10: A10, _ a11: A11, _ a12: A12
    ) -> Output {
        let input = (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12)
        return callAsFunction(input: input, arguments: CapturedArguments(input: input))
    }
}

// Inspired by https://www.objc.io/blog/2018/12/18/atomic-variables/ article

public final class Atomic<A> {
    private let serialAccessQueue = DispatchQueue(label: "ch.proton.atomic_queue")
    private var internalValue: A
    public init(_ value: A) {
        self.internalValue = value
    }

    public var value: A { serialAccessQueue.sync { self.internalValue } }

    public func mutate(_ transform: (inout A) -> Void) {
        serialAccessQueue.sync {
            transform(&self.internalValue)
        }
    }
    
    public func transform<T>(_ transform: (A) -> T) -> T {
        serialAccessQueue.sync {
            transform(self.internalValue)
        }
    }
}
