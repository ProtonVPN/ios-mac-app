//
//  Created on 07/07/2022.
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

import Foundation

public struct RoskomBlockWarningViewModel {
    public let acknowledgeButtonTitle = "Я понимаю"
    public let title = "Роскомнадзор пытается заблокировать ProtonVPN"
    public let description = """
С 31 мая 2022 года предпринимаются активные попытки блокировки Proton VPN в сегментах интернет, подконтрольных РФ.

Мы боремся с этими блокировками и Proton VPN продолжает работать для большинства пользователей. Ситуация постоянно меняется, поэтому если у вас возникнут проблемы с логином или подключением - просто попробуйте повторить это позднее.

Знайте, мы работаем не покладая рук над тем, чтобы победить цензуру. Спасибо за ваше терпение и поддержку!
"""
    public let image: Image = Asset.russiaEmergency.image

    public init() { }
}
