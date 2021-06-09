//
//  Threading.swift
//  Core
//
//  Created by Igor Kulman on 09.06.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

func executeOnUIThread(closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}
