//
//  Created on 20/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

extension Optional where Wrapped: Collection {
    /// Return default value in case the collection is nil or empty
    /// - Parameter defaultValue: the default value you want to assign to the receiver if it is nil or empty.
    /// - Returns: the receiver if it is not nil and non empty, otherwise the provided default value.
    public func unwrappedOr(defaultValue: @autoclosure () -> Wrapped) -> Wrapped {
        guard let `self` = self, !self.isEmpty else {
            return defaultValue()
        }
        return self
    }
}
