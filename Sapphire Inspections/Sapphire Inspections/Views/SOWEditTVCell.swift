//
//  SOWEditTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 2/16/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol SOWEditTVCellDelegate: class {
    func scopeOfWorkUpdated(text: String)
}

class SOWEditTVCell: UITableViewCell, UITextViewDelegate {

    @IBOutlet weak var sowTextView: UITextView!
    @IBOutlet weak var uploadsButton: UIButton!
    
    var uploadsButtonAction: (()->())?
    
    weak var delegate: SOWEditTVCellDelegate?


    @IBAction func uploadsButtonTapped(_ sender: UIButton) {
        uploadsButtonAction?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        self.sowTextView.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    // MARK: UITextViewDelegate
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let textViewText: NSString = textView.text as NSString? ?? ""
        let txtAfterUpdate = textViewText.replacingCharacters(in: range, with: text)

        delegate?.scopeOfWorkUpdated(text: txtAfterUpdate)
        
        return true
    }

}
