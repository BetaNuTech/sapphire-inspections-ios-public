//
//  TemplatesSelectVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/17/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

class TemplatesSelectVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var sections: [sectionTemplate] = []
    var templates: [keyTemplate] = []
    var filteredTemplates: [(key: String, template: Template)] = []
    var keyPropertyToEdit: (key: String, property: Property)?
    var categories: [keyTemplateCategory] = []
    
    var filterString = ""

    var isLoading = false
    
    var templateCategoriesListener: ListenerRegistration?


    deinit {
        if let listener = templateCategoriesListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        isLoading = true

        // Defaults
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

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isLoading {
            presentHUDForConnection()
            setObservers()
        }
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
        
        let key = sections[indexPath.section].keyTemplates[(indexPath as NSIndexPath).row].key
        let template = sections[indexPath.section].keyTemplates[(indexPath as NSIndexPath).row].template

        let cell: TemplateTVCell!
        cell = tableView.dequeueReusableCell(withIdentifier: "templateCell") as? TemplateTVCell
        
        cell.templateName.text = template.name ?? "No Name"
        cell.templateDescription.text = template.description ?? "No Description"
        
        if isTemplateKeySelected(key) {
            cell.templateName.textColor = UIColor.black
            cell.templateDescription.textColor = UIColor.darkGray
            cell.backgroundColor = GlobalColors.veryLightBlue
        } else {
            cell.templateName.textColor = UIColor.darkGray
            cell.templateDescription.textColor = UIColor.lightGray
            cell.backgroundColor = UIColor.white
        }
        
        return cell
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
        
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    // MARK: UITableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = sections[indexPath.section].keyTemplates[(indexPath as NSIndexPath).row].key
        if isTemplateKeySelected(key) {
            deselectTemplateKey(key)
        } else {
            selectTemplateKey(key)
        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
//    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
//        let key = templates[(indexPath as NSIndexPath).row].key
//        if isTemplateKeySelected(key) {
//            deselectTemplateKey(key)
//        } else {
//            selectTemplateKey(key)
//        }
//        
//        tableView.reloadRows(at: [indexPath], with: .none)
//    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    // MARK: Private Methods
    
    func sortTemplates() {
        templates.sort(by: { $0.template.name?.lowercased() ?? "" < $1.template.name?.lowercased() ?? "" } )
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
    
    func setObservers() {
        dbCollectionTemplates().getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                dismissHUDForConnection()

                guard let weakSelf = self else {
                    return
                }
                
                weakSelf.isLoading = false
                
                if let error = error {
                    print("Error getting Templates: \(error)")
                    return
                } else if let querySnapshot = querySnapshot {
                    weakSelf.templates.removeAll()
                    for document in querySnapshot.documents {
                        let newTemplate = (document.documentID, Mapper<Template>().map(JSONObject: document.data())!)
                        weakSelf.templates.append(newTemplate)
                    }
                    weakSelf.sortTemplates()
                    weakSelf.updateSelections()
                    weakSelf.tableView.reloadData()
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
    
    func updateSelections() {
        var index = 0
        for keyTemplate in templates {
            let indexPath = IndexPath(row: index, section: 0)
            if isTemplateKeySelected(keyTemplate.key) {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            } else {
                tableView.deselectRow(at: indexPath, animated: false)
            }
            index += 1
        }
        
        // Remove templates that no longer exist for property
        if let keyPropertyToEdit = keyPropertyToEdit {
            var templateKeysToRemove: [String] = []
            for templateDict in keyPropertyToEdit.property.templates {
                if templates.first(where: { templateDict.key == $0.key } ) == nil {
                    templateKeysToRemove.append(templateDict.key)
                }
            }
            for key in templateKeysToRemove {
                keyPropertyToEdit.property.templates.removeValue(forKey: key)
            }
        }
    }
    
    func isTemplateKeySelected(_ key: String) -> Bool {
        if let templates = keyPropertyToEdit?.property.templates {
            if let templateValue = templates[key] {
                if let fieldValue = templateValue as? FieldValue, fieldValue == FieldValue.delete() {
                    return false
                }
                return true
            }
        }
        
        return false
    }
    
    func selectTemplateKey(_ key: String) {
        guard let keyPropertyToEdit = keyPropertyToEdit else {
            return
        }
        
        keyPropertyToEdit.property.templates[key] = NSNumber(value: true as Bool)
    }
    
    func deselectTemplateKey(_ key: String) {
        guard let keyPropertyToEdit = keyPropertyToEdit else {
            return
        }
        
        keyPropertyToEdit.property.templates[key] = FieldValue.delete()
    }
}
