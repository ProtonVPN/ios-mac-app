//
//  Created on 23/06/2026.
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

#ifndef XPCAuditToken_h
#define XPCAuditToken_h

#import <Foundation/Foundation.h>

/// `NSXPCConnection`'s `auditToken` property is private, for no good reason — Apple lets us properly check the code
/// signature of a raw `xpc_connection_t` via `xpc_connection_set_peer_code_signing_requirement`, but gives NSXPC no
/// such API. The only public option is the endpoint's pid, which rolls over and is open to TOCTTOU attacks. This
/// re-declares the private property so the ProTUN extension's XPC listener can audit connecting peers by audit
/// trailer. (Mirrors `AuditTokenGetter.h` in the macOS app, ported here so the SPM-built extension can use it.)
@interface NSXPCConnection (XPCAuditToken)
@property (nonatomic, readonly) audit_token_t auditToken;
@end

#endif /* XPCAuditToken_h */
