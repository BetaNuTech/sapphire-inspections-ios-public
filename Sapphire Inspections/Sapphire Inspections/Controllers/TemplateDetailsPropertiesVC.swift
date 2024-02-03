//
//  TemplateDetailsPropertiesVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/5/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

class TemplateDetailsPropertiesVC: UIViewController, UITextFieldDelegate, UITextViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var pickerBackgroundView: UIControl!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var deficientItemsSwitch: UISwitch!
    @IBOutlet weak var requireNoteAndPhotoForDIsSwitch: UISwitch!

    
    var categories: [keyTemplateCategory] = []
    
    var dismissHUD = false
    
    var templateCategoriesListener: ListenerRegistration?

    
    deinit {
        if let listener = templateCategoriesListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setObservers()
        
        updateDeficientItemsSwitch()
        updateRequireNoteAndPhotoForDeficientItemsSwitch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            titleField.text = template.name
            descriptionTextView.text = template.description
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Actions
    
    @IBAction func trackDeficientItemsChanged(_ sender: UISwitch) {
        setTrackDeficientItems(enabled: sender.isOn)
        if sender.isOn {
            requireNoteAndPhotoForDIsSwitch.setOn(true, animated: true)
            setRequireNoteAndPhotoForDeficientItems(enabled: true)
        }
    }
    
    @IBAction func requireNoteAndPhotoForDeficientItemsChanged(_ sender: UISwitch) {
        setRequireNoteAndPhotoForDeficientItems(enabled: sender.isOn)
    }
    
    
    // MARK: - Navigation

    @IBAction func categoriesButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
        
        // Show picker view
        if categories.count > 0 {
            pickerBackgroundView.isHidden = false
            updateSelectedCategory(updatePicker: true)
        }
    }
    
    @IBAction func pickerViewBackgroundTapped(_ sender: UIControl) {
        pickerBackgroundView.isHidden = true
    }
    
    // MARK: - Picker Protocols
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return categories.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return categories[row].category.name
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        print("did select row")
        setCategory(categoryKey: categories[row].key)
        updateSelectedCategory(updatePicker: false)
    }

    
    func sortCategories() {
        categories.sort(by: { $0.category.name?.lowercased() ?? "" < $1.category.name?.lowercased() ?? "" } )
        
        // Add Uncategorized, if not present, and move to top
        if let index = categories.firstIndex(where: { $0.key == ""}) {
            let uncategorized = categories.remove(at: index)
            categories.insert(uncategorized, at: 0)
        } else {
            let uncategorized = (key: "", category: Mapper<TemplateCategory>().map(JSON: [:])!)
            uncategorized.category.name = "Uncategorized"
            categories.insert(uncategorized, at: 0)
        }
    }
    
    func updateSelectedCategory(updatePicker: Bool) {
        var pickerIndex = 0
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            if let categoryKey = template.category {
                if let index = categories.firstIndex(where: { $0.key == categoryKey }) {
                    pickerIndex = index
                }
            }
        }
        
        // Set Selected Row
        if updatePicker {
            pickerView.selectRow(pickerIndex, inComponent: 0, animated: false)
        }

        // Update button label
        if categories.count > 0 {
            categoryButton.setTitle(categories[pickerIndex].category.name, for: .normal)
        }
    }
    
    func setCategory(categoryKey: String) {
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            template.category = categoryKey
        }
    }
    
    func setTrackDeficientItems(enabled: Bool) {
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            template.trackDeficientItems = enabled
        }
    }
    
    func updateDeficientItemsSwitch() {
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            deficientItemsSwitch.isOn = template.trackDeficientItems
        }
    }
    
    func setRequireNoteAndPhotoForDeficientItems(enabled: Bool) {
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            template.requireDeficientItemNoteAndPhoto = enabled
        }
    }
    
    func updateRequireNoteAndPhotoForDeficientItemsSwitch() {
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            requireNoteAndPhotoForDIsSwitch.isOn = template.requireDeficientItemNoteAndPhoto
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let textFieldText: NSString = textField.text as NSString? ?? ""
        let txtAfterUpdate = textFieldText.replacingCharacters(in: range, with: string)
        
        
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            template.name = txtAfterUpdate
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        descriptionTextView.becomeFirstResponder()
        
        return false
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let textViewText: NSString = textView.text as NSString? ?? ""
        let txtAfterUpdate = textViewText.replacingCharacters(in: range, with: text)
        
        if let template = TemplateDetailsPageVC.keyTemplate?.template {
            template.description = txtAfterUpdate
        }

        return true
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    func setObservers() {
        presentHUDForConnection()
        
        dbCollectionTemplateCategories().getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Template Categories: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    dismissHUDForConnection()
                } else {
                    print("Template Categories count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
        
                weakSelf.templateCategoriesListener = dbCollectionTemplateCategories().addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        
                        if weakSelf.dismissHUD {
                            dismissHUDForConnection()
                            weakSelf.dismissHUD = false
                        }
                        
                        guard let snapshot = querySnapshot else {
                            print("Error fetching dbCollectionTemplateCategories snapshot: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                let newCategory = (key: diff.document.documentID, category: Mapper<TemplateCategory>().map(JSONObject: diff.document.data())!)
                                weakSelf.categories.append(newCategory)
                                weakSelf.sortCategories()
                                weakSelf.pickerView.reloadAllComponents()
                                weakSelf.updateSelectedCategory(updatePicker: false)
                            } else if (diff.type == .modified) {
                                let changedCategory: (key: String, category: TemplateCategory) = (diff.document.documentID, Mapper<TemplateCategory>().map(JSONObject: diff.document.data())!)
                                if let index = weakSelf.categories.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.categories.remove(at: index)
                                    weakSelf.categories.insert(changedCategory, at: index)
                                    weakSelf.sortCategories()
                                    weakSelf.pickerView.reloadAllComponents()
                                    weakSelf.updateSelectedCategory(updatePicker: false)
                                }
                            } else if (diff.type == .removed) {
                                if let index = weakSelf.categories.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.categories.remove(at: index)
                                    weakSelf.pickerView.reloadAllComponents()
                                    weakSelf.updateSelectedCategory(updatePicker: false)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
