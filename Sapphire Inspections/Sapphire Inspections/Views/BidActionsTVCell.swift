//
//  BidActionsTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/22/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class BidActionsTVCell: UITableViewCell, UITextViewDelegate {

    @IBOutlet weak var action1Button: UIButton!
    @IBOutlet weak var action2Button: UIButton!
    @IBOutlet weak var action3Button: UIButton!
    @IBOutlet weak var action1View: UIView!
    @IBOutlet weak var action2View: UIView!
    @IBOutlet weak var action3View: UIView!
    
    var action1ButtonAction: (()->())?
    var action2ButtonAction: (()->())?
    var action3ButtonAction: (()->())?

    @IBAction func action1ButtonTapped(_ sender: UIButton) {
        action1ButtonAction?()
    }
    @IBAction func action2ButtonTapped(_ sender: UIButton) {
        action2ButtonAction?()
    }
    @IBAction func action3ButtonTapped(_ sender: UIButton) {
        action3ButtonAction?()
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
