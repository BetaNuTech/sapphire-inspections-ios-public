//
//  TemplateTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/07/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class TemplateTVCell: UITableViewCell {

    @IBOutlet weak var templateName: UILabel!
    @IBOutlet weak var templateDescription: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
