//
//  BidCostEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/21/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol BidCostEditTVCellDelegate: class {
    func resetCost()
    func fixedCostUpdated(cost: NSNumber?)
    func rangeCostMinUpdated(costMin: NSNumber?)
    func rangeCostMaxUpdated(costMax: NSNumber?)
}

class BidCostEditTVCell: UITableViewCell {

    @IBOutlet weak var fixedOrRangeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var textField1: UITextField!
    @IBOutlet weak var textField2: UITextField!
    
    weak var delegate: BidCostEditTVCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
                
        textField1.delegate = self
        textField2.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func resetInputs(forIndex segmentedControlIndex: Int) {
        if segmentedControlIndex == 0 {
            
        }
    }
    
    func setCost(costMin: NSNumber?, costMax: NSNumber?) {

        // No Input, set default states/values
        if costMin == nil && costMax == nil {
            fixedOrRangeSegmentedControl.selectedSegmentIndex = 0 // Fixed
            textField1.isHidden = false
            textField2.isHidden = true
            textField1.placeholder = "Fixed Price"
            textField1.text = ""
            textField2.text = ""
            return
        }
        
        // Range Values
        if let costMin = costMin, let costMax = costMax, costMin.doubleValue != costMax.doubleValue {
            fixedOrRangeSegmentedControl.selectedSegmentIndex = 1 // Range
            textField1.isHidden = false
            textField2.isHidden = false
            textField1.placeholder = "Min Price"
            textField2.placeholder = "Max Price"
            let currencyFormatter = NumberFormatter()
            currencyFormatter.maximumFractionDigits = 2
            textField1.text = currencyFormatter.string(from: costMin)
            textField2.text = currencyFormatter.string(from: costMax)
            if costMin.doubleValue == 0 {
                textField1.text = ""
            }
            if costMax.doubleValue == 0 {
                textField2.text = ""
            }
            return
        }

        // Fixed Value
        let fixedCost = (costMin != nil) ? costMin! : costMax!
        fixedOrRangeSegmentedControl.selectedSegmentIndex = 0 // Fixed
        textField1.isHidden = false
        textField2.isHidden = true
        textField1.placeholder = "Fixed Price"
        let currencyFormatter = NumberFormatter()
        currencyFormatter.maximumFractionDigits = 2
        textField1.text = currencyFormatter.string(from: fixedCost)
        if fixedCost.doubleValue == 0 {
            textField1.text = ""
        }
    }
    
    // MARK: Actions

    @IBAction func fixedOrRangeValueChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            textField1.isHidden = false
            textField2.isHidden = true
            textField1.placeholder = "Fixed Price"
            textField1.text = ""
            textField2.text = ""
            delegate?.resetCost()
        } else if sender.selectedSegmentIndex == 1 {
            textField1.isHidden = false
            textField2.isHidden = false
            textField1.placeholder = "Min Price"
            textField2.placeholder = "Max Price"
            textField1.text = ""
            textField2.text = ""
            delegate?.resetCost()
        }
    }
    
}


extension BidCostEditTVCell: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let formatter = NumberFormatter()

        let candidate = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        let separator = formatter.decimalSeparator!

        if candidate == "" {
            if textField == textField1 {
                if fixedOrRangeSegmentedControl.selectedSegmentIndex == 0 {
                    delegate?.fixedCostUpdated(cost: nil)
                } else {
                    delegate?.rangeCostMinUpdated(costMin: nil)
                }
            } else if textField == textField2 {
                delegate?.rangeCostMaxUpdated(costMax: nil)
            }
            return true
        }

        let isWellFormatted = candidate.range(of: "^[0-9]{1,9}([\(separator)][0-9]{0,2})?$", options: .regularExpression) != nil

        if isWellFormatted, let value = formatter.number(from: candidate)?.doubleValue, value >= 0 {
            let number = formatter.number(from: candidate)
            if textField == textField1 {
                if fixedOrRangeSegmentedControl.selectedSegmentIndex == 0 {
                    delegate?.fixedCostUpdated(cost: number)
                } else {
                    delegate?.rangeCostMinUpdated(costMin: number)
                }
            } else if textField == textField2 {
                delegate?.rangeCostMaxUpdated(costMax: number)
            }
            return true
        }

        return false
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField == textField1 {
            if fixedOrRangeSegmentedControl.selectedSegmentIndex == 0 {
                delegate?.fixedCostUpdated(cost: nil)
            } else {
                delegate?.rangeCostMinUpdated(costMin: nil)
            }
        } else if textField == textField2 {
            delegate?.rangeCostMaxUpdated(costMax: nil)
        }
        
        return true
    }
}
