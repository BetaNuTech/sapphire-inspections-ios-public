//
//  JobActionTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/11/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class JobActionTVCell: UITableViewCell, UITextViewDelegate {

    @IBOutlet weak var actionButton: UIButton!
    
    var actionButtonAction: (()->())?

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        actionButtonAction?()
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
