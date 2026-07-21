//
//  Created on 26/05/2026.
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

#pragma once

// Mirrors CF_ENUM / NS_ENUM, tells Swift's clang importer to create a proper enum and strip the common prefix.
#if __has_attribute(enum_extensibility)
#  define IPC_ENUM(_type, _name)                                                  \
       typedef enum __attribute__((enum_extensibility(open))) _name : _type _name; \
       enum __attribute__((enum_extensibility(open))) _name : _type
#else
#  define IPC_ENUM(_type, _name) typedef enum _name : _type _name; enum _name : _type
#endif
