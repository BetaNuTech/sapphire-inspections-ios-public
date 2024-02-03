//
//  TemplateDetailsSectionsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/5/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class TemplateDetailsSectionsVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textEntryView: UIView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var textEntryField: UITextField!
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Defaults
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 36.0;
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true
        
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(TemplateDetailsSectionsVC.keyboardWillShow(_:)),
                                                         name: UIResponder.keyboardWillShowNotification,
                                                         object: nil)
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(TemplateDetailsSectionsVC.keyboardWillHide(_:)),
                                                         name: UIResponder.keyboardWillHideNotification,
                                                         object: nil)
        
        setupLongPressGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TemplateDetailsPageVC.keySectionsWithKeyItems.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if TemplateDetailsPageVC.keySectionsWithKeyItems.count > 0 && (indexPath as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "sectionCell") as! SectionTVCell
            let section = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).row].section
            cell.sectionName.text = section.title ?? ""
            cell.sectionTypeButton.addTarget(self, action: #selector(TemplateDetailsSectionsVC.hitSectionType(button:)), for: .touchUpInside)
            
            switch section.sectionType {
            case TemplateSectionType.single.rawValue:
                cell.sectionTypeButton.setImage(UIImage(named: "single"), for: .normal)
            case TemplateSectionType.multi.rawValue:
                cell.sectionTypeButton.setImage(UIImage(named: "multi"), for: .normal)
            default:
                cell.sectionTypeButton.setImage(UIImage(named: "single"), for: .normal)
            }
            
            return cell
        }
    
        let cell = tableView.dequeueReusableCell(withIdentifier: "addSectionCell")
        return cell!
    }

    // MARK: UITableView Delegates

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).row == TemplateDetailsPageVC.keySectionsWithKeyItems.count {
            tableView.deselectRow(at: indexPath, animated: false)
            let newKey = dbCollectionTemplates().document().documentID
            let newSection: (key: String, section: TemplateSection, keyItems: [ (key: String, item: TemplateItem) ]) = (newKey, TemplateSection(JSONString: "{}")!, [])
            newSection.section.index = TemplateDetailsPageVC.keySectionsWithKeyItems.count
            TemplateDetailsPageVC.keySectionsWithKeyItems.append(newSection)
            
            tableView.reloadData()
            textEntryField.text = ""
            let lastIndexPath = IndexPath(row: TemplateDetailsPageVC.keySectionsWithKeyItems.count - 1, section: 0)
            tableView.selectRow(at: lastIndexPath, animated: true, scrollPosition: .middle)
        } else {
            let templateSection = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).row].section
            textEntryField.text = templateSection.title
        }
        
        textEntryField.isUserInteractionEnabled = true
        textEntryField.becomeFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return ((indexPath as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems.count)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if (destinationIndexPath as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems.count {
            let keySection = TemplateDetailsPageVC.keySectionsWithKeyItems[(sourceIndexPath as NSIndexPath).row]
            TemplateDetailsPageVC.keySectionsWithKeyItems.remove(at: (sourceIndexPath as NSIndexPath).row)
            TemplateDetailsPageVC.keySectionsWithKeyItems.insert(keySection, at: (destinationIndexPath as NSIndexPath).row)
            updateSectionIndices()
        } else {
            alertForDeleting(indexPath: sourceIndexPath)
            tableView.reloadData()  // reload... confirm deletion
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .normal, title: "Delete") { action, index in
            TemplateDetailsPageVC.keySectionsWithKeyItems.remove(at: (indexPath as NSIndexPath).row)
            tableView.reloadData()
        }
        delete.backgroundColor = UIColor.red
        
        return [delete]
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    // MARK: UITextField Delegates
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let textFieldText: NSString = textField.text as NSString? ?? ""
        let txtAfterUpdate = textFieldText.replacingCharacters(in: range, with: string)
        
        guard let selectedIndexPath = tableView.indexPathForSelectedRow else {
            return false
        }
        
        let templateSection = TemplateDetailsPageVC.keySectionsWithKeyItems[(selectedIndexPath as NSIndexPath).row].section
        templateSection.title = txtAfterUpdate
        
        tableView.reloadRows(at: [selectedIndexPath], with: .none)
        tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .middle)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        var newRowSelected = false
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            if (indexPathForSelectedRow as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems.count - 1 {
                let indexPath = IndexPath(row: (indexPathForSelectedRow as NSIndexPath).row + 1, section: 0)
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
                tableView(tableView, didSelectRowAt: indexPath)
                newRowSelected = true
            }
        }
        
        if !newRowSelected {
            textEntryField.resignFirstResponder()
        }
        
        return false
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        textField.isUserInteractionEnabled = false
        textField.text = ""
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
        return true
    }
    
    // MARK: Actions
    
    @objc func hitSectionType(button: UIButton) {
        let buttonPositionInTableView = button.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: buttonPositionInTableView) {
            let section = TemplateDetailsPageVC.keySectionsWithKeyItems[indexPath.row].section
            switch section.sectionType {
            case TemplateSectionType.single.rawValue:
                section.sectionType = TemplateSectionType.multi.rawValue
            case TemplateSectionType.multi.rawValue:
                section.sectionType = TemplateSectionType.single.rawValue
            default:
                section.sectionType = TemplateSectionType.single.rawValue
            }
            
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
    
    func setupLongPressGesture() {
        let longPressGesture:UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        tableView.addGestureRecognizer(longPressGesture)
    }

    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer){
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint) {
                alertForDeleting(indexPath: indexPath)
            }
        }
    }
    
    func alertForDeleting(indexPath: IndexPath) {
        guard (indexPath as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems.count else {
            // Add Row, ignore
            return
        }
        
        let alertController = UIAlertController(title: "Are you sure you want to delete this section?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            DispatchQueue.main.async {
                TemplateDetailsPageVC.keySectionsWithKeyItems.remove(at: (indexPath as NSIndexPath).row)
                self?.updateSectionIndices()
                self?.tableView.reloadData()
                NotificationCenter.default.post(name: NSNotification.Name.TemplateSectionsUpdated, object: nil)  // Updated Templates Items Screen
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    // MARK: Keyboard
    
    @objc func keyboardWillShow(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        let offsetHeight = keyboardData.endFrame.size.height  // nil to use window
        view.layoutIfNeeded()
        UIView.animate(withDuration: keyboardData.animationDuration,
                                   delay: 0,
                                   options: keyboardData.animationCurve,
                                   animations: {
                                    self.bottomConstraint.constant = offsetHeight - TemplateDetailsPageVC.pageControlHeight
                                    self.view.layoutIfNeeded()
            }, completion: nil)
    }
    
    @objc func keyboardWillHide(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        view.layoutIfNeeded()
        UIView.animate(withDuration: keyboardData.animationDuration,
                                   delay: 0,
                                   options: keyboardData.animationCurve,
                                   animations: {
                                    self.bottomConstraint.constant = 0
                                    self.view.layoutIfNeeded()
            }, completion: nil)
    }
    
    func updateSectionIndices() {
        var index = 0
        for keySection in TemplateDetailsPageVC.keySectionsWithKeyItems {
            keySection.section.index = index
            index += 1
        }
    }
}

class SectionTVCell: UITableViewCell {
    @IBOutlet weak var sectionName: UILabel!
    @IBOutlet weak var sectionTypeButton: UIButton!
}
