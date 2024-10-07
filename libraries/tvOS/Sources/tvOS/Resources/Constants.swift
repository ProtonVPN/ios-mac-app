//
//  Created on 28/05/2024.
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

import Foundation

enum Constants {
    static let maxPreferredContentViewWidth: CGFloat = 800

    enum Time {
        /// Servers list refresh
        static let fullServerRefresh: TimeInterval = .hours(3)
    }
    
    enum Legal {
        static let eulaString = """
ProtonVPN App Store 1.1 License Agreement

ProtonVPN is free and open source software, built by Proton AG, rouete de la
Galaise 32, 1228 Plan-les-Ouates, Switzerland and supported by a community of
thousands from all over the world. There are a few things you should know:

- This App Store executable version of ProtonVPN (the "ProtonVPN App") is
made available to you under the terms of the GNU General Public License
Version 3 (GPLv3) (https://www.gnu.org/licenses/gpl-3.0.en.html). This means
you may use, copy and distribute the ProtonVPN App to others under the
conditions of the license. The GPLv3 license also gives you the right to
distribute your modified versions under the conditions of the license.
- You are not granted any trademark rights or licenses to the trademarks of
Proton AG or any party, including without limitation the ProtonVPN name or
logo.
- How we use your personal information and feedback submitted to Proton AG
through the ProtonVPN App is described in the Proton Privacy Policy
(https://proton.me/legal/privacy).
Your use of the ProtonVPN App is submitted to the acceptance of the Proton
Terms of Service (https://proton.me/legal/terms). In this agreement, the term
"Services" shall have the same meaning as under Proton Terms and Conditions.

1. Proton AG and you acknowledge that:
    a. Apple is not responsible for providing any maintenance and support services
    with respect to the ProtonVPN App, as specified herein, or as required under
    applicable law;
    b. Apple is not responsible for addressing any of your claims or claims from
    third parties relating to the ProtonVPN App, including (i) product liability
    claims; (ii) any claim that the ProtonVPN App fails to conform to any applicable
    legal or regulatory requirement; and (iii) claims arising under consumer
    protection, privacy, or similar legislation;
    c. In the event of any third party claim that the ProtonVPN App or your use of
    the ProtonVPN App infringes that third party's intellectual property rights,
    Apple will not be responsible for the investigation, defense, settlement and
    discharge of any such intellectual property infringement claim;
    d. Apple and Apple's subsidiaries are third party beneficiaries of this License
    Agreement and that, upon you acceptance of the terms and conditions of this
    License Agreement, Apple will have the right to enforce this License Agreement
    against you as a third party beneficiary thereof.

2. The ProtonVPN App is provided "as-is." Proton AG, its contributors, licensors,
and distributors, disclaim all warranties, whether express or implied, including
without limitation, warranties that the Services are merchantable and fit for
your particular purposes. You bear the entire risk as to the ProtonVPN App for
your purposes and as to the quality and performance of the ProtonVPN App.
Some jurisdictions do not allow the exclusion or limitation of implied
warranties, so this disclaimer may not apply to you.

3. Except as required by law, Proton AG, its contributors, licensors, and
distributors will not be liable for any indirect, special, incidental, consequential,
punitive, or exemplary damages arising out of or in any way relating to the use
of the ProtonVPN App. The collective liability under these terms will not exceed
$500 (five hundred dollars). Some jurisdictions do not allow the exclusion or
limitation of certain damages, so this exclusion and limitation may not apply to
you.

4. Proton AG may update these terms as necessary from time to time. These
terms may not be modified or canceled without Proton AG's written agreement.

5. These terms are governed by the laws of the state of Switzerland, excluding
its conflict of law provisions. If any portion of these terms is held to be invalid or
unenforceable, the remaining portions will remain in full force and effect. In the
event of a conflict between a translated version of these terms and the English
language version, the English language version shall control.
"""
    }
}
