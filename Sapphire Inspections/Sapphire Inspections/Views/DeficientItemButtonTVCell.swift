//
//  DeficientItemButtonTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/19/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class DeficientItemButtonTVCell: UITableViewCell {

    @IBOutlet weak var button: UIButton!
    
    var buttonActionClosure: (()->())?
    
    @IBAction func buttonTapped(_ sender: UIButton) {
        
        buttonActionClosure?()
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
