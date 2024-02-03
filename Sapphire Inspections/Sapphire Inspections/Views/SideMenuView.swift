//
//  SideMenuView.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/14/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class SideMenuView: UIView {

    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
        SparklePaintCode.drawSideMenuBackground(frame: self.bounds, resizing: .stretch)
    }
 

}
