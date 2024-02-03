//
//  TextFieldEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/19/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol TextFieldEditTVCellDelegate: class {
    func textFieldUpdated(text: String)
}

class TextFieldEditTVCell: UITableViewCell, UITextFieldDelegate {

    @IBOutlet weak var textField: UITextField!
    
    weak var delegate: TextFieldEditTVCellDelegate?

    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        self.textField.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    // MARK: UITextFieldDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let newString = (textField.text! as NSString).replacingCharacters(in: range, with: string)

        delegate?.textFieldUpdated(text: newString)
        
        return true
    }

}
