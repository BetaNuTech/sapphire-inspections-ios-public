//
//  InspectionSectionHeaderView.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 10/27/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class InspectionSectionHeaderView: UITableViewHeaderFooterView {

    static let minHeight: CGFloat = 35.0
    static let leftMargin: CGFloat = 8.0
    static let rightMargin: CGFloat = 43.0
    static let topMargin: CGFloat = 8.0
    static let bottomMargin: CGFloat = 8.0
    static let heightMarginForButtons: CGFloat = 42.0
    
    @IBOutlet weak var sectionLabel: UILabel!
    
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var removeButton: UIButton!
    @IBOutlet weak var singleMultiTypeImageView: UIImageView!
    @IBOutlet weak var collapseButton: UIButton!
    
    var sectionIndex = 0
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
