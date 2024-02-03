//
//  BidVendorSwitchesEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/22/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol BidVendorSwitchesEditTVCellDelegate: class {
    func hasW9Updated(value: Bool)
    func hasInsuranceUpdated(value: Bool)
    func hasLicenseUpdated(value: Bool)
}

class BidVendorSwitchesEditTVCell: UITableViewCell {

    @IBOutlet weak var switch1: UISwitch!
    @IBOutlet weak var switch2: UISwitch!
    @IBOutlet weak var switch3: UISwitch!

    weak var delegate: BidVendorSwitchesEditTVCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
                
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setSwitches(hasW9: Bool?, hasInsurance: Bool?, hasLicense: Bool?) {
        if let value = hasW9 {
            switch1.isOn = value
        } else {
            switch1.isOn = false
        }
        if let value = hasInsurance {
            switch2.isOn = value
        } else {
            switch2.isOn = false
        }
        if let value = hasLicense {
            switch3.isOn = value
        } else {
            switch3.isOn = false
        }

    }
    
    // MARK: Actions

    @IBAction func switch1ValueChanged(_ sender: UISwitch) {
        delegate?.hasW9Updated(value: sender.isOn)
    }

    @IBAction func switch2ValueChanged(_ sender: UISwitch) {
        delegate?.hasInsuranceUpdated(value: sender.isOn)
    }

    @IBAction func switch3ValueChanged(_ sender: UISwitch) {
        delegate?.hasLicenseUpdated(value: sender.isOn)
    }

}

