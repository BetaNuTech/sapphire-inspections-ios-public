//
//  BidScopeEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/21/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import RadioButton

protocol BidScopeEditTVCellDelegate: class {
    func scopeUpdated(scope: BidScope)
}

class BidScopeEditTVCell: UITableViewCell {

    @IBOutlet weak var radio1: RadioButton!
    @IBOutlet weak var radio2: RadioButton!
    
    weak var delegate: BidScopeEditTVCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        radio1.groupButtons = [radio1, radio2]
        
        let imageSelected = UIImage(named: "radio_button_selected")?.tintedImage(tintColor: GlobalColors.blue)
        let imageUnselected = UIImage(named: "radio_button_unselected")

        radio1.setImage(imageUnselected, for: .normal)
        radio1.setImage(imageSelected, for: .selected)
        radio2.setImage(imageUnselected, for: .normal)
        radio2.setImage(imageSelected, for: .selected)
        
        radio1.setTitle("", for: .normal)
        radio1.setTitle("", for: .selected)
        radio2.setTitle("", for: .normal)
        radio2.setTitle("", for: .selected)
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func selectedScope() -> BidScope? {
        
        if radio1.isSelected {
            return BidScope.local
        }
        if radio2.isSelected {
            return BidScope.national
        }

        return nil
    }
    
    func setScope(scope: BidScope?) {
        
        radio1.deselectAllButtons()

        guard let scope = scope else {
            return
        }
        
        switch scope {
        case .local:
            radio1.isSelected = true
        case .national:
            radio2.isSelected = true
        }
    }
    
    // MARK: Actions
    
    @IBAction func radio1Tapped(_ sender: RadioButton) {
        delegate?.scopeUpdated(scope: .local)
    }
    
    @IBAction func radio2Tapped(_ sender: RadioButton) {
        delegate?.scopeUpdated(scope: .national)
    }

}
