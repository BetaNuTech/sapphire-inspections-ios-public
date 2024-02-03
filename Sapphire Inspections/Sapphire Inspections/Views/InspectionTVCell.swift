//
//  InspectionTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/30/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class InspectionTVCell: UITableViewCell {

    @IBOutlet weak var inspectorName: UILabel!
    @IBOutlet weak var creationDate: UILabel!
    @IBOutlet weak var lastUpdateDate: UILabel!
    @IBOutlet weak var score: UILabel!
    @IBOutlet weak var incompletePieView: UIView!
    @IBOutlet weak var scoreView: UIStackView!
    @IBOutlet weak var templateLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!

    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
