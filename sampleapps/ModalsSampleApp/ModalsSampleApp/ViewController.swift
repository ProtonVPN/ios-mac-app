//
//  Created on 10/02/2022.
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

import Modals
import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let modalsFactory = ModalsFactory(colors: Colors())
        
        let upsellViewController = modalsFactory.upsellViewController(constants: Constants())
        present(upsellViewController, animated: true, completion: nil)
    }
}

struct Constants: UpsellConstantsProtocol {
    var numberOfDevices: Int = 10
    var numberOfServers: Int = 1300
    var numberOfCountries: Int = 23
}

struct Colors: ModalsColors {
    var background: UIColor
    var text: UIColor
    var brand: UIColor
    var weakText: UIColor
    
    init() {
        background = .black
        text = .white
        brand = UIColor(red: 77/255, green: 163/255, blue: 88/255, alpha: 1)
        weakText = UIColor(red: 156/255, green: 160/255, blue: 170/255, alpha: 1)
    }
}
