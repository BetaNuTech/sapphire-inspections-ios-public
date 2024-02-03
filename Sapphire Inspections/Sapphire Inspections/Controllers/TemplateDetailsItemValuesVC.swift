//
//  TemplateDetailsItemValuesVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 11/23/17.
//  Copyright © 2017 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class TemplateDetailsItemValuesVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource, ItemElementsTVCellDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var valueEditView: UIView!
    @IBOutlet weak var pickerView: UIPickerView!
    
    var indexPathToEdit: IndexPath?
    var valueIndexToEdit: Int = 0
    
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
    
    // MARK: Actions
    
    @IBAction func valueEditViewBackgroundTapped(_ sender: UIControl) {
        
        valueEditView.isHidden = true
    }
    
    // MARK: UIPicker

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 101
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        return "\(row)"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        guard let indexPath = indexPathToEdit else {
            print("ERROR: indexPathToEdit not set")
            return
        }
        
        guard let cell = tableView.cellForRow(at: indexPath) as? ItemElementsTVCell  else {
            print("ERROR: No cell for indexPathToEdit")
            return
        }
        
        guard let item = cell.item else {
            print("ERROR: No item for cell")
            return
        }
        
        switch valueIndexToEdit {
        case 0:
            item.mainInputZeroValue = row
        case 1:
            item.mainInputOneValue = row
        case 2:
            item.mainInputTwoValue = row
        case 3:
            item.mainInputThreeValue = row
        case 4:
            item.mainInputFourValue = row
        default:
            print("ERROR: Index for value out of range")
        }
        
        tableView.reloadRows(at: [indexPath], with: .automatic)
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
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    func itemElementsTVCellEditValue(for cell: ItemElementsTVCell, at index: Int) {
        if let indexPath = tableView.indexPath(for: cell) {
            indexPathToEdit = indexPath
            valueIndexToEdit = index
            
            // Show value selector
            valueEditView.isHidden = false
            
            if let item = cell.item {
                var value: Int = 0
                switch valueIndexToEdit {
                case 0:
                    value = item.mainInputZeroValue ?? 0
                case 1:
                    value = item.mainInputOneValue ?? 0
                case 2:
                    value = item.mainInputTwoValue ?? 0
                case 3:
                    value = item.mainInputThreeValue ?? 0
                case 4:
                    value = item.mainInputFourValue ?? 0
                default:
                    print("ERROR: Index for value out of range")
                }
                
                pickerView.selectRow(value, inComponent: 0, animated: false)
            }
        }
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
