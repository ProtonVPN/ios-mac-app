//
//  Created on 2022-03-04.
//
//  Copyright (c) 2022 Proton AG
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

#ifndef AuditTokenGetter_h
#define AuditTokenGetter_h

#import <Foundation/Foundation.h>

/// The audit token property of an NSXPCConnection is private, for no good reason. Apple lets us "properly"
/// check the code signature of an `xpc_connection_t` using `xpc_connection_set_peer_code_signing_requirement`,
/// but gives us no such luxury for NSXPCConnections. The best we can do with public API is to check the pid of
/// the endpoint, but this also presents security challenges as pids are known to roll over and can thus be subject
/// to TOCTTOU attacks. This simple interface exposes the private property to us and lets us access it normally.
@interface NSXPCConnection(AuditTokenGetter)
@property (nonatomic, readonly) audit_token_t auditToken;
@end

#endif /* AuditTokenGetter_h */
