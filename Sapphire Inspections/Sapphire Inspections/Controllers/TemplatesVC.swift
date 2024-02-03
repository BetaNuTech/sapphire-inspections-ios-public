//
//  TemplatesVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/31/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

typealias keyTemplate = (key: String, template: Template)
typealias sectionTemplate = (categoryKey: String, categoryTitle: String, keyTemplates: [keyTemplate])

class TemplatesVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    
    var sections: [sectionTemplate] = []
    var templates: [keyTemplate] = []
    var filteredTemplates: [keyTemplate] = []
    var keyTemplateToEdit: keyTemplate?
    var keyTemplateToEditIsACopy = false
    var userListener: ListenerRegistration?
    var templatesListener: ListenerRegistration?
    var templateCategoriesListener: ListenerRegistration?

    var categories: [keyTemplateCategory] = []
    
    var filterString = ""
    
    var dismissHUD = false

    deinit {
        if let listener = userListener {
            listener.remove()
        }
        if let listener = templatesListener {
            listener.remove()
        }
        if let listener = templateCategoriesListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Defaults
        addButton.isEnabled = false
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 61.0;
        tableView.keyboardDismissMode = UIScrollView.KeyboardDismissMode.onDrag
        
        // Setup
        let nib = UINib(nibName: "CategorySectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "CategorySectionHeader")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 30.0

        setObservers()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        updateSections()
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].keyTemplates.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "templateCell") as! TemplateTVCell
        let template = sections[indexPath.section].keyTemplates[(indexPath as NSIndexPath).row].template
        
        cell.templateName.text = template.name ?? "No Name"
        cell.templateDescription.text = template.description ?? "No Description"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let keyTemplates = sections[indexPath.section].keyTemplates

        if (indexPath as NSIndexPath).row < keyTemplates.count {
            keyTemplateToEdit = keyTemplates[(indexPath as NSIndexPath).row]
            performSegue(withIdentifier: "editTemplate", sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let keyTemplates = sections[indexPath.section].keyTemplates
        
        let copy = UITableViewRowAction(style: .normal, title: "Copy") { [weak self] action, index in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                // Copy selected template
                if (indexPath as NSIndexPath).row < keyTemplates.count {
                    let selectedKeyTemplate = keyTemplates[(indexPath as NSIndexPath).row]
                    let copiedTemplate = Template(JSON: selectedKeyTemplate.template.toJSON())!
                    var templateToCopy = (key: "", template: copiedTemplate)
                    let newKey = dbCollectionTemplates().document().documentID
                    templateToCopy.key = newKey // New Key
                    weakSelf.keyTemplateToEdit = templateToCopy
                    weakSelf.keyTemplateToEditIsACopy = true
                    weakSelf.performSegue(withIdentifier: "editTemplate", sender: weakSelf)
                }
            }
        }
        copy.backgroundColor = GlobalColors.veryLightBlue
        
        let edit = UITableViewRowAction(style: .normal, title: "Edit") { [weak self] action, index in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if (indexPath as NSIndexPath).row < keyTemplates.count {
                    weakSelf.keyTemplateToEdit = keyTemplates[(indexPath as NSIndexPath).row]
                    weakSelf.performSegue(withIdentifier: "editTemplate", sender: weakSelf)
                }
            }
        }
        edit.backgroundColor = GlobalColors.darkBlue
        
        let delete = UITableViewRowAction(style: .normal, title: "Delete") { [weak self] action, index in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if (indexPath as NSIndexPath).row < keyTemplates.count {
                     let keyTemplate = keyTemplates[(indexPath as NSIndexPath).row]
                     weakSelf.alertForDeletingTemplate(keyTemplate)
                }
            }
        }
        delete.backgroundColor = UIColor.red
        
        return [delete, edit, copy]
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "CategorySectionHeader")
        let header = cell as! CategorySectionHeader
        header.titleLabel.text = sections[section].categoryTitle
        header.titleLabel.textColor = UIColor.white
        header.background.backgroundColor = UIColor.darkGray

        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if let profile = currentUserProfile, !profile.isDisabled {
            return profile.admin || profile.corporate
        }
        
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        // This method is for showing slide-to-actions
        
        //        if editingStyle == .Delete {
        //            let propertyKey = properties[indexPath.row].key
        //            alertForDeletingProperty(propertyKey)
        //        }
    }
    
//    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
//        return 61.0
//    }
//    
//    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
//        
//        return UITableViewAutomaticDimension
//    }
    
    
    // MARK: UITableView Delegates
    
//    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
//        if let profile = currentUserProfile, admin = profile.admin where admin {
//            self.keyTemplateToEdit = self.templates[indexPath.row]
//            //self.performSegueWithIdentifier("inspections", sender: self)
//        }
//    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "editTemplate" {
            TemplateDetailsPageVC.keyTemplateToEdit = keyTemplateToEdit
            TemplateDetailsPageVC.isACopiedTemplate = keyTemplateToEditIsACopy
        }
        
        keyTemplateToEdit = nil // Reset
        keyTemplateToEditIsACopy = false // Reset
    }
    
    // MARK: Private Methods
    
    func sortTemplates() {
        templates.sort(by: { $0.template.name?.lowercased() ?? "" < $1.template.name?.lowercased() ?? "" } )
        filteredTemplates.sort(by: { $0.template.name?.lowercased() ?? "" < $1.template.name?.lowercased() ?? "" } )
    }
    
    func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    print("Current User Profile Updated, observed by TemplatesVC")
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()), !profile.isDisabled {
                            weakSelf.addButton.isEnabled = profile.admin || profile.corporate
                        } else {
                            weakSelf.addButton.isEnabled = false
                        }
                    }
                }
            })
        }
        
        presentHUDForConnection()
        
        
        dbCollectionTemplates().getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Templates: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    dismissHUDForConnection()
                } else {
                    print("Templates count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
                
                
                weakSelf.templatesListener = dbCollectionTemplates().addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                    
                        guard let snapshot = querySnapshot else {
                            if weakSelf.dismissHUD {
                                dismissHUDForConnection()
                                weakSelf.dismissHUD = false
                            }
                            print("Error fetching dbCollectionTemplates snapshot: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                if weakSelf.dismissHUD {
                                    dismissHUDForConnection()
                                    weakSelf.dismissHUD = false
                                }
                                
                                let newTemplate = (diff.document.documentID, Mapper<Template>().map(JSONObject: diff.document.data())!)
                                weakSelf.templates.append(newTemplate)
                                weakSelf.sortTemplates()
                                weakSelf.filterTemplates()
                                weakSelf.tableView.reloadData()
                            } else if (diff.type == .modified) {
                                let changedTemplate: (key: String, template: Template) = (diff.document.documentID, Mapper<Template>().map(JSONObject: diff.document.data())!)
                                if let index = weakSelf.templates.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.templates.remove(at: index)
                                    weakSelf.templates.insert(changedTemplate, at: index)
                                    weakSelf.sortTemplates()
                                    weakSelf.filterTemplates()
                                    weakSelf.tableView.reloadData()
                                }
                            } else if (diff.type == .removed) {
                                if let index = weakSelf.templates.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.templates.remove(at: index)
                                    weakSelf.filterTemplates()
                                    weakSelf.tableView.reloadData()
                                }
                            }
                        }
                    }
                }
            }
        }

        templateCategoriesListener = dbCollectionTemplateCategories().addSnapshotListener { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
            
                guard let snapshot = querySnapshot else {
                    print("Error fetching dbCollectionTemplateCategories snapshot: \(error!)")
                    return
                }
                snapshot.documentChanges.forEach { diff in
                    if (diff.type == .added) {
                        let newCategory = (diff.document.documentID, Mapper<TemplateCategory>().map(JSONObject: diff.document.data())!)
                        weakSelf.categories.append(newCategory)
                        weakSelf.tableView.reloadData()
                    } else if (diff.type == .modified) {
                        let changedCategory: (key: String, category: TemplateCategory) = (diff.document.documentID, Mapper<TemplateCategory>().map(JSONObject: diff.document.data())!)
                        if let index = weakSelf.categories.index( where: { $0.key == diff.document.documentID} ) {
                            weakSelf.categories.remove(at: index)
                            weakSelf.categories.insert(changedCategory, at: index)
                            weakSelf.tableView.reloadData()
                        }
                    } else if (diff.type == .removed) {
                        if let index = weakSelf.categories.index( where: { $0.key == diff.document.documentID} ) {
                            weakSelf.categories.remove(at: index)
                            weakSelf.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterString = searchText
        filterTemplates()
        
        tableView.reloadData()
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filterTemplates() {
        filteredTemplates = templates.filter({ ($0.template.name ?? "").lowercased().contains(filterString.lowercased()) || ($0.template.description ?? "").lowercased().contains(filterString.lowercased()) ||
            (categoryTitleForKey(categoryKey: $0.template.category ?? "") ?? "uncategorized").lowercased().contains(filterString.lowercased()) })
//        for template in filteredTemplates {
//            print("name = \(template.template.name ?? "")")
//        }
//        print("filteredTemplates.count = \(filteredTemplates.count)")
    }
    
    func templatesAfterFilter() -> [(key: String, template: Template)] {
        if filterString != "" {
            return filteredTemplates
        } else {
            return templates
        }
    }
    
    func updateSections() {
        let defaultCategoryTitle = "Uncategorized"
        let keyTemplates = templatesAfterFilter()
        var newSections: [sectionTemplate] = []
        
        for keyTemplate in keyTemplates {
            var category = keyTemplate.template.category ?? ""
            // Lookup Category Title
            let categoryTitle = categoryTitleForKey(categoryKey: category) ?? defaultCategoryTitle
            if categoryTitle == defaultCategoryTitle {
                category = ""  // Remove key to merge uncategorized
            }
            if let categorySectionIndex = newSections.firstIndex(where: { $0.categoryKey == category }) {
                // Update existing section
                let categorySection = newSections[categorySectionIndex]
                var keyTemplates = categorySection.keyTemplates
                keyTemplates.append(keyTemplate)
                newSections[categorySectionIndex] = (categoryKey: category, categoryTitle: categoryTitle, keyTemplates: keyTemplates)
            } else {
                // Add new section
                newSections.append((categoryKey: category, categoryTitle: categoryTitle, keyTemplates: [keyTemplate]))
            }
        }

        // Sort by Category name, "Uncategorized" first
        newSections.sort(by: { $0.categoryTitle.lowercased() < $1.categoryTitle.lowercased() })
        
        // Move defaultCategoryTitle to top, if it exists
        if let categorySectionIndex = newSections.firstIndex(where: { $0.categoryTitle == defaultCategoryTitle }) {
            let section = newSections.remove(at: categorySectionIndex)
            newSections.insert(section, at: newSections.endIndex)
        }
        
        sections = newSections
    }
    
    func categoryTitleForKey(categoryKey: String) -> String? {
        if let index = categories.firstIndex(where: {$0.key == categoryKey}) {
            return categories[index].category.name
        }
        
        return nil
    }
    
    // MARK: Alerts
    
    func alertForDeletingTemplate(_ keyTemplate: (key: String, template: Template)) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this template?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            SVProgressHUD.show()
            dbDocumentTemplateWith(documentId: keyTemplate.key).delete { (error) in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showMessagePrompt(error!.localizedDescription)
                    } else {
                        Notifications.sendTemplateDeletion(template: keyTemplate.template)
                    }
                    
                    SVProgressHUD.dismiss()
                }
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
}
