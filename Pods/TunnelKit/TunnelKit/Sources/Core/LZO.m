//
//  LZO.m
//  TunnelKit
//
//  Created by Davide De Rosa on 3/18/19.
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

#import "LZO.h"
#import "ZeroingData.h"

static NSString *const LZOClassName = @"StandardLZO";

static Class LZOClass()
{
    NSBundle *bundle = [NSBundle bundleForClass:[ZeroingData class]];
    return [bundle classNamed:LZOClassName];
}

BOOL LZOIsSupported()
{
    return LZOClass() != nil;
}

id<LZO> LZOCreate()
{
    return [[LZOClass() alloc] init];
}
