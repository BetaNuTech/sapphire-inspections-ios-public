//
//  TextViewEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 12/30/21.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol TextViewEditTVCellDelegate: class {
    func textViewUpdated(text: String)
}

class TextViewEditTVCell: UITableViewCell, UITextViewDelegate {

    @IBOutlet weak var textView: UITextView!
    
    weak var delegate: TextViewEditTVCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        self.textView.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    // MARK: UITextViewDelegate
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let textViewText: NSString = textView.text as NSString? ?? ""
        let txtAfterUpdate = textViewText.replacingCharacters(in: range, with: text)

        delegate?.textViewUpdated(text: txtAfterUpdate)
        
        return true
    }

}
