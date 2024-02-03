//
//  TemplateDetailsItemElementsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/5/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

typealias ActionIconNames = (iconName0: String, iconName1: String, iconName2: String, iconName3: String, iconName4: String)
let twoActions_checkmarkX_iconNames: ActionIconNames = ("checkmark", "cancel", "", "", "")
let twoActions_thumbs_iconNames: ActionIconNames = ("thumbs_up", "thumbs_down", "", "", "")
let threeActions_checkmarkExclamationX_iconNames: ActionIconNames = ("checkmark", "caution", "cancel", "", "")
let threeActions_ABC_iconNames: ActionIconNames = ("A", "B", "C", "", "")
let fiveActions_oneToFive_iconNames: ActionIconNames = ("one", "two", "three", "four", "five")
let oneAction_notes_iconNames: ActionIconNames = ("note", "", "", "", "")

typealias ActionIconValues = (iconValue0: Int, iconValue1: Int, iconValue2: Int, iconValue3: Int, iconValue4: Int)
let twoActions_checkmarkX_default_iconValues: ActionIconValues = (3, 0, 0, 0, 0)
let twoActions_thumbs_default_iconValues: ActionIconValues = (3, 0, 0, 0, 0)
let threeActions_checkmarkExclamationX_default_iconValues: ActionIconValues = (5, 3, 0, 0, 0)
let threeActions_ABC_default_iconValues: ActionIconValues = (3, 1, 0, 0, 0)
let fiveActions_oneToFive_default_iconValues: ActionIconValues = (1, 2, 3, 4, 5)
let oneAction_notes_default_iconValues: ActionIconValues = (0, 0, 0, 0, 0)


let defaultTemplateItemActions = TemplateItemActions.TwoActions_checkmarkX

enum TemplateItemActions: String {
    case TwoActions_checkmarkX = "twoactions_checkmarkx"
    case TwoActions_thumbs = "twoactions_thumbs"
    case ThreeActions_checkmarkExclamationX = "threeactions_checkmarkexclamationx"
    case ThreeActions_ABC = "threeactions_abc"
    case FiveActions_oneToFive = "fiveactions_onetofive"
    case OneAction_notes = "oneaction_notes"
}

import UIKit

class TemplateDetailsItemElementsVC: UIViewController, UITableViewDataSource, UITableViewDelegate, ItemElementsTVCellDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Defaults
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 104.0
        tableView.isEditing = false
        let nib = UINib(nibName: "InspectionSectionHeaderView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "InspectionSectionHeaderView")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.estimatedSectionHeaderHeight = 27
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }
    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return TemplateDetailsPageVC.keySectionsWithKeyItems.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TemplateDetailsPageVC.keySectionsWithKeyItems[section].keyItems.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
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
        if let sectionLabel = TemplateDetailsPageVC.keySectionsWithKeyItems[section].section.title, let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "InspectionSectionHeaderView") as? InspectionSectionHeaderView {
            let labelHeight = sectionLabel.heightWithConstrainedWidth(width: tableView.frame.size.width - InspectionSectionHeaderView.leftMargin - InspectionSectionHeaderView.rightMargin, font: header.sectionLabel.font)
            return max(InspectionSectionHeaderView.topMargin + labelHeight + InspectionSectionHeaderView.bottomMargin, InspectionSectionHeaderView.minHeight)
        }
        return InspectionSectionHeaderView.minHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
        let type = item.templateItemType()
        switch type {
        case .main:
            let cell = tableView.dequeueReusableCell(withIdentifier: "itemElementsCell") as! ItemElementsTVCell
            cell.item = item
            cell.delegate = self
            cell.itemName.text = item.title ?? ""
            
            if let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
                item.mainInputType = mainInputTypeEnum.rawValue // update value
                updateMainInputViewsForCell(cell, item: item, mainInputTypeEnum: mainInputTypeEnum)
                
            } else {
                item.mainInputType = defaultTemplateItemActions.rawValue // update value
                updateMainInputViewsForCell(cell, item: item, mainInputTypeEnum: defaultTemplateItemActions)
            }
            
            // Change values to ?
            cell.actionIconZeroValueLabel.text = (cell.actionIconZeroValueLabel.text != "") ? "?" : ""
            cell.actionIconOneValueLabel.text = (cell.actionIconOneValueLabel.text != "") ? "?" : ""
            cell.actionIconTwoValueLabel.text = (cell.actionIconTwoValueLabel.text != "") ? "?" : ""
            cell.actionIconThreeValueLabel.text = (cell.actionIconThreeValueLabel.text != "") ? "?" : ""
            cell.actionIconFourValueLabel.text = (cell.actionIconFourValueLabel.text != "") ? "?" : ""
            
            let enableNotes = item.notes ?? true
            item.notes = enableNotes
            cell.notesImageView.alpha = enableNotes ? 1.0 : 0.2
            
            let enableCamera = item.photos ?? true
            item.photos = enableCamera
            cell.cameraImageView.alpha = enableCamera ? 1.0 : 0.2
            
            return cell
        case .textInput:
            let cell = tableView.dequeueReusableCell(withIdentifier: "itemElementsTextInputCell") as! ItemElementsTextInputTVCell
            cell.item = item
            cell.itemName.text = item.title
            cell.itemTextInputField.text = item.textInputValue
            
            return cell
        case .signature:
            let cell = tableView.dequeueReusableCell(withIdentifier: "itemElementsSignatureCell") as! ItemElementsSignatureTVCell
            cell.item = item
            
            return cell
        case .unsupported:
            let cell = UITableViewCell()
            cell.textLabel?.text = "Unsupported (Update App)"
            return cell
        }
    }
    
    func itemElementsTVCellUpdated(_ itemElementsTVCell: ItemElementsTVCell) {
        if let indexPath = tableView.indexPath(for: itemElementsTVCell) {
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
    
    func itemElementsTVCellEditValue(for cell: ItemElementsTVCell, at index: Int) {
        // NA
    }
    
    // MARK: UITableView Delegates
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //let templateItem = TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems[(indexPath as NSIndexPath).row].item
        // TODO: do something with this
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return ((indexPath as NSIndexPath).row < TemplateDetailsPageVC.keySectionsWithKeyItems[(indexPath as NSIndexPath).section].keyItems.count)
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
    // MARK: Private Methods
    func updateMainInputViewsForCell(_ cell: ItemElementsTVCell, item: TemplateItem, mainInputTypeEnum: TemplateItemActions) {
        switch mainInputTypeEnum {
        case .TwoActions_checkmarkX:
            cell.actionIconZeroImageView.image  = twoActions_checkmarkX_iconNames.iconName0 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName0) : nil
            cell.actionIconOneImageView.image   = twoActions_checkmarkX_iconNames.iconName1 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName1) : nil
            cell.actionIconTwoImageView.image   = twoActions_checkmarkX_iconNames.iconName2 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName2) : nil
            cell.actionIconThreeImageView.image = twoActions_checkmarkX_iconNames.iconName3 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName3) : nil
            cell.actionIconFourImageView.image  = twoActions_checkmarkX_iconNames.iconName4 != "" ? UIImage(named: twoActions_checkmarkX_iconNames.iconName4) : nil
            
            item.setMainValues(mainInputTypeEnum: mainInputTypeEnum)

            cell.actionIconZeroValueLabel.text = "\(item.mainInputZeroValue!)"
            cell.actionIconOneValueLabel.text = "\(item.mainInputOneValue!)"
            cell.actionIconTwoValueLabel.text = ""
            cell.actionIconThreeValueLabel.text = ""
            cell.actionIconFourValueLabel.text = ""
        case .TwoActions_thumbs:
            cell.actionIconZeroImageView.image  = twoActions_thumbs_iconNames.iconName0 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName0) : nil
            cell.actionIconOneImageView.image   = twoActions_thumbs_iconNames.iconName1 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName1) : nil
            cell.actionIconTwoImageView.image   = twoActions_thumbs_iconNames.iconName2 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName2) : nil
            cell.actionIconThreeImageView.image = twoActions_thumbs_iconNames.iconName3 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName3) : nil
            cell.actionIconFourImageView.image  = twoActions_thumbs_iconNames.iconName4 != "" ? UIImage(named: twoActions_thumbs_iconNames.iconName4) : nil

            item.setMainValues(mainInputTypeEnum: mainInputTypeEnum)

            cell.actionIconZeroValueLabel.text = "\(item.mainInputZeroValue!)"
            cell.actionIconOneValueLabel.text = "\(item.mainInputOneValue!)"
            cell.actionIconTwoValueLabel.text = ""
            cell.actionIconThreeValueLabel.text = ""
            cell.actionIconFourValueLabel.text = ""
        case .ThreeActions_checkmarkExclamationX:
            cell.actionIconZeroImageView.image  = threeActions_checkmarkExclamationX_iconNames.iconName0 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName0) : nil
            cell.actionIconOneImageView.image   = threeActions_checkmarkExclamationX_iconNames.iconName1 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName1) : nil
            cell.actionIconTwoImageView.image   = threeActions_checkmarkExclamationX_iconNames.iconName2 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName2) : nil
            cell.actionIconThreeImageView.image = threeActions_checkmarkExclamationX_iconNames.iconName3 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName3) : nil
            cell.actionIconFourImageView.image  = threeActions_checkmarkExclamationX_iconNames.iconName4 != "" ? UIImage(named: threeActions_checkmarkExclamationX_iconNames.iconName4) : nil

            item.setMainValues(mainInputTypeEnum: mainInputTypeEnum)
            
            cell.actionIconZeroValueLabel.text = "\(item.mainInputZeroValue!)"
            cell.actionIconOneValueLabel.text = "\(item.mainInputOneValue!)"
            cell.actionIconTwoValueLabel.text = "\(item.mainInputTwoValue!)"
            cell.actionIconThreeValueLabel.text = ""
            cell.actionIconFourValueLabel.text = ""
        case .ThreeActions_ABC:
            cell.actionIconZeroImageView.image  = threeActions_ABC_iconNames.iconName0 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName0) : nil
            cell.actionIconOneImageView.image   = threeActions_ABC_iconNames.iconName1 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName1) : nil
            cell.actionIconTwoImageView.image   = threeActions_ABC_iconNames.iconName2 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName2) : nil
            cell.actionIconThreeImageView.image = threeActions_ABC_iconNames.iconName3 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName3) : nil
            cell.actionIconFourImageView.image  = threeActions_ABC_iconNames.iconName4 != "" ? UIImage(named: threeActions_ABC_iconNames.iconName4) : nil

            item.setMainValues(mainInputTypeEnum: mainInputTypeEnum)
            
            cell.actionIconZeroValueLabel.text = "\(item.mainInputZeroValue!)"
            cell.actionIconOneValueLabel.text = "\(item.mainInputOneValue!)"
            cell.actionIconTwoValueLabel.text = "\(item.mainInputTwoValue!)"
            cell.actionIconThreeValueLabel.text = ""
            cell.actionIconFourValueLabel.text = ""
        case .FiveActions_oneToFive:
            cell.actionIconZeroImageView.image  = fiveActions_oneToFive_iconNames.iconName0 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName0) : nil
            cell.actionIconOneImageView.image   = fiveActions_oneToFive_iconNames.iconName1 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName1) : nil
            cell.actionIconTwoImageView.image   = fiveActions_oneToFive_iconNames.iconName2 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName2) : nil
            cell.actionIconThreeImageView.image = fiveActions_oneToFive_iconNames.iconName3 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName3) : nil
            cell.actionIconFourImageView.image  = fiveActions_oneToFive_iconNames.iconName4 != "" ? UIImage(named: fiveActions_oneToFive_iconNames.iconName4) : nil

            item.setMainValues(mainInputTypeEnum: mainInputTypeEnum)
            
            cell.actionIconZeroValueLabel.text = "\(item.mainInputZeroValue!)"
            cell.actionIconOneValueLabel.text = "\(item.mainInputOneValue!)"
            cell.actionIconTwoValueLabel.text = "\(item.mainInputTwoValue!)"
            cell.actionIconThreeValueLabel.text = "\(item.mainInputThreeValue!)"
            cell.actionIconFourValueLabel.text = "\(item.mainInputFourValue!)"
        case .OneAction_notes:
            cell.actionIconZeroImageView.image  = oneAction_notes_iconNames.iconName0 != "" ? UIImage(named: oneAction_notes_iconNames.iconName0) : nil
            cell.actionIconOneImageView.image   = oneAction_notes_iconNames.iconName1 != "" ? UIImage(named: oneAction_notes_iconNames.iconName1) : nil
            cell.actionIconTwoImageView.image   = oneAction_notes_iconNames.iconName2 != "" ? UIImage(named: oneAction_notes_iconNames.iconName2) : nil
            cell.actionIconThreeImageView.image = oneAction_notes_iconNames.iconName3 != "" ? UIImage(named: oneAction_notes_iconNames.iconName3) : nil
            cell.actionIconFourImageView.image  = oneAction_notes_iconNames.iconName4 != "" ? UIImage(named: oneAction_notes_iconNames.iconName4) : nil

            item.setMainValues(mainInputTypeEnum: mainInputTypeEnum)
            
            cell.actionIconZeroValueLabel.text = ""
            cell.actionIconOneValueLabel.text = ""
            cell.actionIconTwoValueLabel.text = ""
            cell.actionIconThreeValueLabel.text = ""
            cell.actionIconFourValueLabel.text = ""
        }
    }

}

protocol ItemElementsTVCellDelegate: class {
    func itemElementsTVCellUpdated(_ itemElementsTVCell: ItemElementsTVCell)
    func itemElementsTVCellEditValue(for cell: ItemElementsTVCell, at index: Int)
}

class ItemElementsTVCell: UITableViewCell {
    var item: TemplateItem?
    weak var delegate: ItemElementsTVCellDelegate?
    
    @IBOutlet weak var itemName: UILabel!
    
    @IBOutlet weak var actionIconZeroImageView: UIImageView!
    @IBOutlet weak var actionIconOneImageView: UIImageView!
    @IBOutlet weak var actionIconTwoImageView: UIImageView!
    @IBOutlet weak var actionIconThreeImageView: UIImageView!
    @IBOutlet weak var actionIconFourImageView: UIImageView!
    
    @IBOutlet weak var actionIconZeroValueLabel: UILabel!
    @IBOutlet weak var actionIconOneValueLabel: UILabel!
    @IBOutlet weak var actionIconTwoValueLabel: UILabel!
    @IBOutlet weak var actionIconThreeValueLabel: UILabel!
    @IBOutlet weak var actionIconFourValueLabel: UILabel!
    
    @IBOutlet weak var notesImageView: UIImageView!
    @IBOutlet weak var cameraImageView: UIImageView!
    
    @IBAction func mainInputTypeButtonTapped(_ sender: AnyObject) {
        if let item = item {
            if let mainInputType = item.mainInputType, let mainInputTypeEnum = TemplateItemActions(rawValue: mainInputType.lowercased()) {
                item.mainInputType = mainInputTypeEnum.rawValue // update value
                toggleMainInputForItem(item, mainInputTypeEnum: mainInputTypeEnum)
                
            } else {
                item.mainInputType = defaultTemplateItemActions.rawValue // update value
                toggleMainInputForItem(item, mainInputTypeEnum: defaultTemplateItemActions)
            }

            // reload row
            if let delegate = delegate {
                delegate.itemElementsTVCellUpdated(self)
            }
        }
    }
    
    @IBAction func mainInputZeroValue(_ sender: UIButton) {
        if actionIconZeroValueLabel.text == "" {
            return
        }
        
        if let delegate = delegate {
            delegate.itemElementsTVCellEditValue(for: self, at: 0)
        }
    }
    @IBAction func mainInputOneValue(_ sender: UIButton) {
        if actionIconOneValueLabel.text == "" {
            return
        }
        
        if let delegate = delegate {
            delegate.itemElementsTVCellEditValue(for: self, at: 1)
        }
    }
    @IBAction func mainInputTwoValue(_ sender: UIButton) {
        if actionIconTwoValueLabel.text == "" {
            return
        }
        
        if let delegate = delegate {
            delegate.itemElementsTVCellEditValue(for: self, at: 2)
        }
    }
    @IBAction func mainInputThreeValue(_ sender: UIButton) {
        if actionIconThreeValueLabel.text == "" {
            return
        }
        
        if let delegate = delegate {
            delegate.itemElementsTVCellEditValue(for: self, at: 3)
        }
    }
    @IBAction func mainInputFourValue(_ sender: UIButton) {
        if actionIconFourValueLabel.text == "" {
            return
        }
        
        if let delegate = delegate {
            delegate.itemElementsTVCellEditValue(for: self, at: 4)
        }
    }
    
    @IBAction func noteButtonTapped(_ sender: AnyObject) {
        if let item = item {
            if let enableNotes = item.notes {
                item.notes = !enableNotes
            } else {
                item.notes = true
            }
            
            // reload row
            if let delegate = delegate {
                delegate.itemElementsTVCellUpdated(self)
            }
        }
    }
    
    @IBAction func cameraButtonTapped(_ sender: AnyObject) {
        if let item = item {
            if let enablePhotos = item.photos {
                item.photos = !enablePhotos
            } else {
                item.photos = true
            }
            
            // reload row
            if let delegate = delegate {
                delegate.itemElementsTVCellUpdated(self)
            }
        }
    }
    
    func toggleMainInputForItem(_ item: TemplateItem, mainInputTypeEnum: TemplateItemActions) {
        switch mainInputTypeEnum {
        case .TwoActions_checkmarkX:
            item.mainInputType = TemplateItemActions.TwoActions_thumbs.rawValue
            item.mainInputZeroValue = twoActions_thumbs_default_iconValues.iconValue0
            item.mainInputOneValue = twoActions_thumbs_default_iconValues.iconValue1
            item.mainInputTwoValue = twoActions_thumbs_default_iconValues.iconValue2
            item.mainInputThreeValue = twoActions_thumbs_default_iconValues.iconValue3
            item.mainInputFourValue = twoActions_thumbs_default_iconValues.iconValue4
        case .TwoActions_thumbs:
            item.mainInputType = TemplateItemActions.ThreeActions_checkmarkExclamationX.rawValue
            item.mainInputZeroValue = threeActions_checkmarkExclamationX_default_iconValues.iconValue0
            item.mainInputOneValue = threeActions_checkmarkExclamationX_default_iconValues.iconValue1
            item.mainInputTwoValue = threeActions_checkmarkExclamationX_default_iconValues.iconValue2
            item.mainInputThreeValue = threeActions_checkmarkExclamationX_default_iconValues.iconValue3
            item.mainInputFourValue = threeActions_checkmarkExclamationX_default_iconValues.iconValue4
        case .ThreeActions_checkmarkExclamationX:
            item.mainInputType = TemplateItemActions.ThreeActions_ABC.rawValue
            item.mainInputZeroValue = threeActions_ABC_default_iconValues.iconValue0
            item.mainInputOneValue = threeActions_ABC_default_iconValues.iconValue1
            item.mainInputTwoValue = threeActions_ABC_default_iconValues.iconValue2
            item.mainInputThreeValue = threeActions_ABC_default_iconValues.iconValue3
            item.mainInputFourValue = threeActions_ABC_default_iconValues.iconValue4
        case .ThreeActions_ABC:
            item.mainInputType = TemplateItemActions.FiveActions_oneToFive.rawValue
            item.mainInputZeroValue = fiveActions_oneToFive_default_iconValues.iconValue0
            item.mainInputOneValue = fiveActions_oneToFive_default_iconValues.iconValue1
            item.mainInputTwoValue = fiveActions_oneToFive_default_iconValues.iconValue2
            item.mainInputThreeValue = fiveActions_oneToFive_default_iconValues.iconValue3
            item.mainInputFourValue = fiveActions_oneToFive_default_iconValues.iconValue4
        case .FiveActions_oneToFive:
            item.mainInputType = TemplateItemActions.OneAction_notes.rawValue
            item.mainInputZeroValue = oneAction_notes_default_iconValues.iconValue0
            item.mainInputOneValue = oneAction_notes_default_iconValues.iconValue1
            item.mainInputTwoValue = oneAction_notes_default_iconValues.iconValue2
            item.mainInputThreeValue = oneAction_notes_default_iconValues.iconValue3
            item.mainInputFourValue = oneAction_notes_default_iconValues.iconValue4
        case .OneAction_notes:
            item.mainInputType = TemplateItemActions.TwoActions_checkmarkX.rawValue
            item.mainInputZeroValue = twoActions_checkmarkX_default_iconValues.iconValue0
            item.mainInputOneValue = twoActions_checkmarkX_default_iconValues.iconValue1
            item.mainInputTwoValue = twoActions_checkmarkX_default_iconValues.iconValue2
            item.mainInputThreeValue = twoActions_checkmarkX_default_iconValues.iconValue3
            item.mainInputFourValue = twoActions_checkmarkX_default_iconValues.iconValue4
        }
    }
}

class ItemElementsTextInputTVCell: UITableViewCell, UITextFieldDelegate {
    var item: TemplateItem?
    
    @IBOutlet weak var itemName: UILabel!
    @IBOutlet weak var itemTextInputField: UITextField!

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let item = item {
            item.textInputValue = textField.text ?? ""
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

class ItemElementsSignatureTVCell: UITableViewCell {
    var item: TemplateItem?
    
    @IBOutlet weak var signatureImageView: UIImageView!
}
