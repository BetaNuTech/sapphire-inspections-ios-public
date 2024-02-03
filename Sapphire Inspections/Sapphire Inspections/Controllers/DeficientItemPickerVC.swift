//
//  DeficientItemPickerVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 4/16/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol DeficientItemPickerVCDelegate: class {
    func deficientItemPickerValueUpdated(value: String, element: DICellElement)
}

class DeficientItemPickerVC: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    
    var headerText = ""
    var element: DICellElement?
    var pickerValues: [String] = []
    var pickerTitleValues: [String] = []
    var currentValueIndex = 0
    weak var delegate: DeficientItemPickerVCDelegate?
    
    var deficientItemHasUpdates = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = headerText
        navItem.title = headerText
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        pickerView.reloadAllComponents()
        if pickerTitleValues.count > 0 && currentValueIndex < pickerTitleValues.count {
            pickerView.selectRow(currentValueIndex, inComponent: 0, animated: true)
        }
        
        updateNavButtons()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateNavButtons() {
        if deficientItemHasUpdates {
            addDoneButton()
            // Now using table button to save
            //            addSaveButton()
        } else {
            removeDoneButton()
        }
    }
    
    func addDoneButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if !rightBarButtonItems.contains(doneButton) {
            rightBarButtonItems.append(doneButton)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func removeDoneButton() {
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if let index = rightBarButtonItems.index(of: doneButton) {
            rightBarButtonItems.remove(at: index)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    
    // MARK: - Picker Delegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerTitleValues.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        return pickerTitleValues[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        if let element = element {
            delegate?.deficientItemPickerValueUpdated(value: pickerValues[row], element: element)
        }
        
        deficientItemHasUpdates = true
        updateNavButtons()
    }
    
    

    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
