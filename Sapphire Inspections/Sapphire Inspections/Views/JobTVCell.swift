//
//  JobTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 12/15/21.
//  Copyright © 2021 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class JobTVCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var createdAtLabel: UILabel!
    @IBOutlet weak var updatedAtLabel: UILabel!
    @IBOutlet weak var jobTypeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
