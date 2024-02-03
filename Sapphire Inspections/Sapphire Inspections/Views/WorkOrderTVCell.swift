//
//  WorkOrderTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/12/20.
//  Copyright © 2020 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class WorkOrderTVCell: UITableViewCell {

    @IBOutlet weak var idCreatedAtLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var propertiesLabel: UILabel!
    @IBOutlet weak var delinquentLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
