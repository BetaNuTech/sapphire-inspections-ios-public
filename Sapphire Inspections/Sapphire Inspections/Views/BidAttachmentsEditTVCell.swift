//
//  BidAttachmentsEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/22/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class BidAttachmentsEditTVCell: UITableViewCell, UITextViewDelegate {

    @IBOutlet weak var uploadsButton: UIButton!
    
    var uploadsButtonAction: (()->())?

    @IBAction func uploadsButtonTapped(_ sender: UIButton) {
        uploadsButtonAction?()
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
