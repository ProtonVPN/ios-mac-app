//
//  Result+Extensions.swift
//  Core
//
//  Created by Igor Kulman on 02.09.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

extension Result where Success == Void {
    public static var success: Self { .success(()) }
}

extension Result {
    public func invoke(success: @escaping (Success) -> Void, failure: @escaping (Error) -> Void) {
        switch self {
        case let .success(data):
            success(data)
        case let .failure(error):
            failure(error)
        }
    }
}
