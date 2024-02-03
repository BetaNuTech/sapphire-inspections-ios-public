//
//  DeficientItemTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/1/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class DeficientItemTVCell: UITableViewCell {

    @IBOutlet weak var responsibilityGroupLabel: UILabel!
    @IBOutlet weak var dueDateLabel: UILabel!
    @IBOutlet weak var itemTItleLabel: UILabel!
    @IBOutlet weak var sectionTitleLabel: UILabel!
    @IBOutlet weak var deficientInputImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
