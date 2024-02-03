//
//  JobTrelloCardTVCell.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/4/22.
//  Copyright © 2022 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol JobTrelloCardTVCellDelegate: class {
    func trelloCardURLUpdated(text: String)
}

class JobTrelloCardTVCell: UITableViewCell, UITextViewDelegate {

    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var openButton: UIButton!

    var trelloCardURL: String?

    weak var viewController: UIViewController?
    weak var delegate: JobTrelloCardTVCellDelegate?

    @IBAction func openButtonTapped(_ sender: UIButton) {
        guard let urlString = trelloCardURL else {
            print("trelloCardURL not set")
            return
        }
        guard let url = URL(string: urlString) else {
            return
        }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    @IBAction func editButtonTapped(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Update Trello Card URL", message: nil, preferredStyle: .alert)
        
        alertController.addTextField { [weak self] (textField) in
            textField.text = self?.trelloCardURL
            textField.placeholder = "Enter URL Address"
            textField.keyboardType = .URL
        }

        // add the buttons/actions to the view controller
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] (action) in
            self?.viewController?.view.endEditing(true)
        }
        let updateAction = UIAlertAction(title: "Update", style: .default) { [weak self] _ in
            self?.viewController?.view.endEditing(true)

            let urlString = alertController.textFields![0].text ?? ""
            
            self?.trelloCardURL = urlString
            self?.delegate?.trelloCardURLUpdated(text: urlString)
            self?.openButton.isEnabled = (urlString != "")
        }

        alertController.addAction(cancelAction)
        alertController.addAction(updateAction)

        viewController?.present(alertController, animated: true, completion: nil)
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
