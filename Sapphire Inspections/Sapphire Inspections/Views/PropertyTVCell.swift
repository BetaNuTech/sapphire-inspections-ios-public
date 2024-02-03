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
    @IBOutlet weak var pendingDICount: UILabel!
    @IBOutlet weak var actionsRequiredDICount: UILabel!
    @IBOutlet weak var followupRequiredDICount: UILabel!
    @IBOutlet weak var deficientItemsButton: UIButton!
    
    var deficientItemsClosure: (()->())?

    @IBAction func deficientItemsTapped(_ sender: UIButton) {
        deficientItemsClosure?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
