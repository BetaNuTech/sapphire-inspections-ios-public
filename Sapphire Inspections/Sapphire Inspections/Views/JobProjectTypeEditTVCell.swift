//
//  JobProjectTypeEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 1/24/21.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import RadioButton

protocol JobProjectTypeEditTVCellDelegate: class {
    func projectTypeUpdated(type: JobProjectType)
}

class JobProjectTypeEditTVCell: UITableViewCell {

    @IBOutlet weak var radio1: RadioButton!
    @IBOutlet weak var radio2: RadioButton!
    @IBOutlet weak var radio3: RadioButton!
    @IBOutlet weak var radio4: RadioButton!
    
    weak var delegate: JobProjectTypeEditTVCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        radio1.groupButtons = [radio1, radio2, radio3, radio4]
        
        let imageSelected = UIImage(named: "radio_button_selected")?.tintedImage(tintColor: GlobalColors.blue)
        let imageUnselected = UIImage(named: "radio_button_unselected")

        radio1.setImage(imageUnselected, for: .normal)
        radio1.setImage(imageSelected, for: .selected)
        radio2.setImage(imageUnselected, for: .normal)
        radio2.setImage(imageSelected, for: .selected)
        radio3.setImage(imageUnselected, for: .normal)
        radio3.setImage(imageSelected, for: .selected)
        radio4.setImage(imageUnselected, for: .normal)
        radio4.setImage(imageSelected, for: .selected)
        
        radio1.setTitle("", for: .normal)
        radio1.setTitle("", for: .selected)
        radio2.setTitle("", for: .normal)
        radio2.setTitle("", for: .selected)
        radio3.setTitle("", for: .normal)
        radio3.setTitle("", for: .selected)
        radio4.setTitle("", for: .normal)
        radio4.setTitle("", for: .selected)
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func selectedProjectType() -> JobProjectType? {
        
        if radio1.isSelected {
            return JobProjectType.small_pm
        }
        if radio2.isSelected {
            return JobProjectType.small_hybrid
        }
        if radio3.isSelected {
            return JobProjectType.large_am
        }
        if radio4.isSelected {
            return JobProjectType.large_sc
        }

        return nil
    }
    
    func setProjectType(projectType: JobProjectType?) {
        
        radio1.deselectAllButtons()
        
        guard let projectType = projectType else {
            return
        }

        switch projectType {
        case .small_pm:
            radio1.isSelected = true
        case .small_hybrid:
            radio2.isSelected = true
        case .large_am:
            radio3.isSelected = true
        case .large_sc:
            radio4.isSelected = true
        }
    }
    
    // MARK: Actions
    
    @IBAction func radio1Tapped(_ sender: RadioButton) {
        delegate?.projectTypeUpdated(type: .small_pm)
    }
    
    @IBAction func radio2Tapped(_ sender: RadioButton) {
        delegate?.projectTypeUpdated(type: .small_hybrid)
    }
    
    @IBAction func radio3Tapped(_ sender: RadioButton) {
        delegate?.projectTypeUpdated(type: .large_am)
    }
    
    @IBAction func radio4Tapped(_ sender: RadioButton) {
        delegate?.projectTypeUpdated(type: .large_sc)
    }
    

}
