//
//  JobBidsTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/8/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class JobBidsTVCell: UITableViewCell, UITextViewDelegate {

    var expediteButtonAction: (()->())?

    @IBAction func expediteButtonTapped(_ sender: UIButton) {
        expediteButtonAction?()
    }
    
    @IBOutlet var bidsLabel: UILabel!
    @IBOutlet var expediteButton: UIButton!
    @IBOutlet var completedApprovedLabel: UILabel!
    @IBOutlet var completedApprovedBidsLabel: UILabel!
    @IBOutlet var openBidsLabel: UILabel!
    @IBOutlet var rejectedBidsLabel: UILabel!
    @IBOutlet var incompleteBidsLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
