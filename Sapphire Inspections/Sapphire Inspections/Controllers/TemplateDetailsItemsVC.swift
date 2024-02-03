//
//  TemplateDetailsItemsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/5/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class TemplateDetailsItemsVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

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
        let nib = UINib(nibName: "InspectionSectionHeaderView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "InspectionSectionHeaderView")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.estimatedSectionHeaderHeight = 27
        
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(TemplateDetailsItemsVC.keyboardWillShow(_:)),
                                                         name: UIResponder.keyboardWillShowNotification,
                                                         object: nil)
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(TemplateDetailsItemsVC.keyboardWillHide(_:)),
                                                         name: UIResponder.keyboardWillHideNotification,
                                                         object: nil)
        
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(TemplateDetailsItemsVC.updateUI(_:)),
                                                         name: NSNotification.Name.TemplateSectionsUpdated,
                                                         object: nil)
        
        setupLongPressGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }
    
    @objc func updateUI(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in
            print("updateUI")
            self?.tableView.reloadData()
        }
    }

    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        print("numberOfSections = \(TemplateDetailsPageVC.keySectionsWithKeyItems.count)")
        return TemplateDetailsPageVC.keySectionsWithKeyItems.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("numberOfRowsInSection, Section Index = \(section)")
        guard section < TemplateDetailsPageVC.keySectionsWithKeyItems.count else {
            print("ERROR: Section Index out of bounds.")
            tableView.reloadData()
            return 0
        }
        return TemplateDetailsPageVC.keySectionsWithKeyItems[section].keyItems.count + 1
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        print("viewForHeaderInSection, Section Index = \(section)")
        guard section < TemplateDetailsPageVC.keySectionsWithKeyItems.count else {
            print("ERROR: Section Index out of bounds.")
            tableView.reloadData()
            return nil
        }
        // Dequeue with the reuse identifier
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "InspectionSectionHeaderView") as? InspectionSectionHeaderView {
            let section = TemplateDetailsPageVC.keySectionsWithKeyItems[section].section
            header.sectionLabel.text = section.title
            
            switch section.sectionType {
            case TemplateSectionType.single.rawValue:
                header.singleMultiTypeImageView.image = UIImage(named: "single_white")
            case TemplateSectionType.multi.rawValue:
                header.singleMultiTypeImageView.image = UIImage(named: "multi_white")
            default:
                header.singleMultiTypeImageView.image = UIImage(named: "single_white")
            }
            
            return header
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        print("heightForHeaderInSection, Section Index = \(section)")
        guard section < TemplateDetailsPageVC.keySectionsWithKeyItems.count else {
            print("ERROR: Section Index out of bounds.")
            tableView.reloadData()
            return 0.0
        }
        if let sectionLabel = TemplateDetailsPageVC.keySectionsWithKeyItems[section].section.title, let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "InspectionSectionHeaderView") as? InspectionSectionHeaderView {
            let labelHeight = sectionLabel.heightWithConstrainedWidth(width: tableView.frame.size.width - InspectionSectionHeaderView.leftMargin - InspectionSectionHeaderView.rightMargin, font: header.sectionLabel.font)
            return max(InspectionSectionHeaderView.topMargin + labelHeight + InspectionSectionHeaderView.bottomMargin, InspectionSectionHeaderView.minHeight)
        }
        return InspectionSectionHeaderView.minHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("cellForRowAt, Section Index = \(indexPath.section)")
        guard indexPath.section < TemplateDetailsPageVC.keySectionsWithKeyItems.count else {
            print("ERROR: Section Index out of bounds.")
            tableView.reloadData()
            let cell = UITableViewCell()
            return cell
        }
        if TemplateDetailsPageVC.keySectionsWithKeyItems[indexPath.section].keyItems.count > 0 && indexPath.row < TemplateDetailsPageVC.keySectionsWithKeyItems[indexPath.section].keyItems.count {
            let item = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
            let type = item.templateItemType()
            switch type {
            case .main:
                let cell = tableView.dequeueReusableCell(withIdentifier: "itemCell") as! ItemTVCell
                cell.itemName.text = item.title ?? ""
                cell.changeItemTypeClosure = {
                    DispatchQueue.main.async { [weak self] in
                        let templateItem = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
                        templateItem.changeItemType()
                        self?.tableView.reloadRows(at: [indexPath], with: .none)
                        self?.textEntryField.resignFirstResponder()
                        self?.textEntryField.text = ""
                    }
                }
                return cell
            case .textInput:
                let cell = tableView.dequeueReusableCell(withIdentifier: "textInputCell") as! ItemTVCell
                cell.itemName.text = item.title ?? ""
                cell.changeItemTypeClosure = {
                    DispatchQueue.main.async { [weak self] in
                        let templateItem = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
                        templateItem.changeItemType()
                        self?.tableView.reloadRows(at: [indexPath], with: .none)
                        self?.textEntryField.resignFirstResponder()
                        self?.textEntryField.text = ""
                    }
                }
                return cell
            case .signature:
                let cell = tableView.dequeueReusableCell(withIdentifier: "signatureCell") as! ItemTVCell
                cell.changeItemTypeClosure = {
                    DispatchQueue.main.async { [weak self] in
                        let templateItem = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
                        templateItem.changeItemType()
                        self?.tableView.reloadRows(at: [indexPath], with: .none)
                        self?.textEntryField.resignFirstResponder()
                        self?.textEntryField.text = ""
                    }
                }
                return cell
            case .unsupported:
                let cell = UITableViewCell()
                cell.textLabel?.text = "Unsupported (Update App)"
                return cell
            }
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "addItemCell") as! ItemAddTVCell
        cell.addItemButton.addTarget(self, action: #selector(TemplateDetailsItemsVC.hitItemAdd(button:)), for: .touchUpInside)
        cell.addTextInputButton.addTarget(self, action: #selector(TemplateDetailsItemsVC.hitTextInputAdd(button:)), for: .touchUpInside)
        cell.addSignatureButton.addTarget(self, action: #selector(TemplateDetailsItemsVC.hitSignatureAdd(button:)), for: .touchUpInside)

        return cell
    }

    // MARK: UITableView Delegates
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == TemplateDetailsPageVC.keySectionsWithKeyItems[indexPath.section].keyItems.count {
            tableView.deselectRow(at: indexPath, animated: false)
        } else {
            let templateItem = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
            if templateItem.itemType != TemplateItemType.signature.rawValue {
                textEntryField.text = templateItem.title
                textEntryField.isUserInteractionEnabled = true
                textEntryField.becomeFirstResponder()
            } else {
                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        print("canEditRowAt, Section Index = \(indexPath.section)")
        guard indexPath.section < TemplateDetailsPageVC.keySectionsWithKeyItems.count else {
            print("ERROR: Section Index out of bounds.")
            tableView.reloadData()
            return false
        }
        return ((indexPath as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems.count)
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
        if (destinationIndexPath as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems[(destinationIndexPath as NSIndexPath).section].keyItems.count {
            let keyItem = TemplateDetailsPageVC.keySectionsWithKeyItems[(sourceIndexPath as NSIndexPath).section].keyItems[(sourceIndexPath as NSIndexPath).row]
            TemplateDetailsPageVC.keySectionsWithKeyItems[(sourceIndexPath as NSIndexPath).section].keyItems.remove(at: (sourceIndexPath as NSIndexPath).row)
            TemplateDetailsPageVC.keySectionsWithKeyItems[(destinationIndexPath as NSIndexPath).section].keyItems.insert(keyItem, at: (destinationIndexPath as NSIndexPath).row)
            // update section
            keyItem.item.sectionId = TemplateDetailsPageVC.keySectionsWithKeyItems[(destinationIndexPath as NSIndexPath).section].key
            updateItemIndicesForSection((sourceIndexPath as NSIndexPath).section)
            updateItemIndicesForSection((destinationIndexPath as NSIndexPath).section)
        } else {
            alertForDeleting(indexPath: sourceIndexPath)
            tableView.reloadData()  // Reload... confirm deletion
        }
    }
    
//    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
//        let delete = UITableViewRowAction(style: .Normal, title: "Delete") { action, index in
//            TemplateDetailsPageVC.keySectionsWithKeyItems.removeAtIndex(indexPath.row)
//            tableView.reloadData()
//        }
//        delete.backgroundColor = UIColor.redColor()
//        
//        return [delete]
//    }
    
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
        
        let templateItem = TemplateDetailsPageVC.keySectionsWithKeyItems[(selectedIndexPath as NSIndexPath).section].keyItems[(selectedIndexPath as NSIndexPath).row].item
        templateItem.title = txtAfterUpdate
        
        tableView.reloadRows(at: [selectedIndexPath], with: .none)
        tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .middle)
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        var newRowSelected = false
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            // Same section
            if (indexPathForSelectedRow as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPathForSelectedRow as NSIndexPath).section].keyItems.count - 1 {
                let indexPath = IndexPath(row: (indexPathForSelectedRow as NSIndexPath).row + 1, section: (indexPathForSelectedRow as NSIndexPath).section)
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
                tableView(tableView, didSelectRowAt: indexPath)
                newRowSelected = true
            } else if (indexPathForSelectedRow as NSIndexPath).section < tableView.numberOfSections - 1 {
                if TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPathForSelectedRow as NSIndexPath).section + 1].keyItems.count > 0 {
                    let indexPath = IndexPath(row: 0, section: (indexPathForSelectedRow as NSIndexPath).section + 1)
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
                    tableView(tableView, didSelectRowAt: indexPath)
                    newRowSelected = true
                }
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
    
    @objc func hitItemAdd(button: UIButton) {
        let buttonPositionInTableView = button.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: buttonPositionInTableView) {
            self.addNewItem(indexPath: indexPath, isTextInput: false, itemType: .main)
        }
    }
    
    @objc func hitTextInputAdd(button: UIButton) {
        let buttonPositionInTableView = button.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: buttonPositionInTableView) {
            self.addNewItem(indexPath: indexPath, isTextInput: true, itemType: .textInput)
        }
    }
    
    @objc func hitSignatureAdd(button: UIButton) {
        let buttonPositionInTableView = button.convert(CGPoint.zero, to: tableView)
        if let indexPath = tableView.indexPathForRow(at: buttonPositionInTableView) {
            self.addNewItem(indexPath: indexPath, isTextInput: false, itemType: .signature)
        }
    }
    
    func addNewItem(indexPath: IndexPath, isTextInput: Bool, itemType: TemplateItemType) {
        let newKey = dbCollectionTemplates().document().documentID
        let newTemplateItem: (key: String, item: TemplateItem) = (newKey, TemplateItem(JSONString: "{}")!)
        newTemplateItem.item.index = TemplateDetailsPageVC.keySectionsWithKeyItems[indexPath.section].keyItems.count
        newTemplateItem.item.sectionId = TemplateDetailsPageVC.keySectionsWithKeyItems[indexPath.section].key
        newTemplateItem.item.isTextInputItem = isTextInput
        newTemplateItem.item.itemType = itemType.rawValue
        TemplateDetailsPageVC.keySectionsWithKeyItems[indexPath.section].keyItems.append(newTemplateItem)
        
        tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
        if itemType != .signature {
            textEntryField.text = ""
            let lastIndexPath = IndexPath(row: (indexPath as NSIndexPath).row, section: (indexPath as NSIndexPath).section)
            tableView.selectRow(at: lastIndexPath, animated: true, scrollPosition: .middle)
            textEntryField.isUserInteractionEnabled = true
            textEntryField.becomeFirstResponder()
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
        guard (indexPath as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems.count else {
            // Add Row, ignore
            return
        }
        
        let alertController = UIAlertController(title: "Are you sure you want to delete this item?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            DispatchQueue.main.async {
                TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems.remove(at: (indexPath as NSIndexPath).row)
                // update section indices
                self?.updateItemIndicesForSection((indexPath as NSIndexPath).section)
                // Reload Section only
                let sections = NSMutableIndexSet()
                sections.add((indexPath as NSIndexPath).section)
                self?.tableView.reloadSections(sections as IndexSet, with: .automatic)
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }

    // MARK: Keyboard
    
    @objc func keyboardWillShow(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        let offsetHeight = keyboardData.endFrame.size.height
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
    
    func updateItemIndicesForSection(_ section: Int) {
        var index = 0
        for keyItem in TemplateDetailsPageVC.keySectionsWithKeyItems[section].keyItems {
            keyItem.item.index = index
            index += 1
        }
    }
}

class ItemTVCell: UITableViewCell {
    @IBOutlet weak var itemName: UILabel!
    
    var changeItemTypeClosure: (()->())?

    @IBAction func changeItemTypeTapped(_ sender: UIButton) {
        changeItemTypeClosure?()
    }
}

class ItemAddTVCell: UITableViewCell {
    @IBOutlet weak var addItemButton: UIButton!
    @IBOutlet weak var addTextInputButton: UIButton!
    @IBOutlet weak var addSignatureButton: UIButton!
}
