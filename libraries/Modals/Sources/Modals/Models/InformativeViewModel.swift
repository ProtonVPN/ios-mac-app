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

public struct InformativeViewModel {
    public let acknowledgeButtonTitle = "Я понимаю"
    public let title = "Роскомнадзор пытается заблокировать ProtonVPN"
    public let description = "И хотя мы не можем магическим образом избавиться от этой блокировки, мы делаем все возможное, чтобы помочь вам ее обойти. Из-за данной блокировки подключение к нашему VPN сервису иногда может быть затруднено. Уверяем вас, что мы по-прежнему защищаем ваше право на свободный доступ к информации и что наши инженеры работают над решением этой проблемы. Искренне просим вас не ставить нам плохие оценки в App Store: мы должны сохранить рейтинг 4+, иначе мы будем вынуждены прекратить работу нашего сервиса в России."
    public let image: Image = Asset.russiaEmergency.image

    public init() { }
}
