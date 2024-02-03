//
//  BluestoneWhiteLogoView.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/15/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class BluestoneWhiteLogoView: UIView {

    override func draw(_ rect: CGRect) {
        SparklePaintCode.drawBluestoneWhiteLogo(frame: self.bounds, resizing: .stretch)
    }

}
