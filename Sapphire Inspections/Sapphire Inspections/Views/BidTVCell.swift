//
//  BidTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/14/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class BidTVCell: UITableViewCell {

    @IBOutlet weak var vendorLabel: UILabel!
    @IBOutlet weak var scopeLabel: UILabel!
    @IBOutlet weak var additionalDataLabel: UILabel!
    @IBOutlet weak var costView: UIView!
    @IBOutlet weak var costLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
