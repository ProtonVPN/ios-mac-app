//
//  Created on 17.07.2026 by Larissa Perara.
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

# NEProviders 
This package contains the code responsible for connection with the ProTUN core framework extension. 

## Setup 
Get the Nexus host from a teammate and export it in your shell profile (e.g. `~/.zshrc`) as CI_NEXUS_URL.

## Every time the ProTUN version changes

Run the setup script after making the change to the `Package.swift`. The script will parse the file and update the mirrors accordingly to match the new version changed in the `Package.swift`.

```bash
   ./Integration/Scripts/setup-mirrors.sh
```

If it completes without an error, you're done — no need to inspect any
files manually for routine use.

> **Note:** if `CI_NEXUS_URL` isn't set, the script will fail with clear
> instructions rather than silently doing nothing.

## Verification 
If you'd like to verify that this setup has been properly applied follow the steps below: 

1. Verify the mirror file exists and the values in it. 
```bash
cat libraries/Core/NEProviders/.swiftpm/configuration/mirrors.json
```

2. Verify that it is reaching the mirrored URL 
``` bash 
rm -rf libraries/Core/NEProviders/.build
cd libraries/Core/NEProviders
swift package resolve --verbose 2>&1 | grep -i nexus
```
