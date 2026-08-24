//
//  Created on 11/08/2026.
//
//  Copyright (c) 2026 Proton AG
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

import Foundation
import GRDB
import Localization

/// Folds diacritics and case out of a display name, so that, for example, ORDER BY ranks "Genève" beside "Geneva".
nonisolated(unsafe) let normalizedName = DatabaseFunction(
    "NORMALIZED_NAME",
    argumentCount: 1,
    pure: true
) { dbValues in
    String.fromDatabaseValue(dbValues[0])?.normalized
}
