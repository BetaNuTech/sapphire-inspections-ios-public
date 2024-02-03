//
//  TeamTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 6/10/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class TeamTVCell: UITableViewCell {

    @IBOutlet weak var teamName: UILabel!
    @IBOutlet weak var pendingDICount: UILabel!
    @IBOutlet weak var actionsRequiredDICount: UILabel!
    @IBOutlet weak var followupRequiredDICount: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
