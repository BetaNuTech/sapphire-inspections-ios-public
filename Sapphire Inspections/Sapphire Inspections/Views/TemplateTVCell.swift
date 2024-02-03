//
//  PropertyTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/30/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class PropertyTVCell: UITableViewCell {

    @IBOutlet weak var propertyImageView: UIImageView!
    @IBOutlet weak var propertyName: UILabel!
    @IBOutlet weak var propertyAddress12: UILabel!
    @IBOutlet weak var propertyCityStateZip: UILabel!
    @IBOutlet weak var propertyInspections: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
