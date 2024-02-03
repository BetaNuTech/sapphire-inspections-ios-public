//
//  TemplateSelectVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/18/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

protocol TemplateSelectVCDelegate: class {
    func templateSelected(_ keyTemplate: (key: String, template: Template))
    func templateSelectionCancelled()
}

class TemplateSelectVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    var keyProperty: (key: String, property: Property)?
    weak var delegate: TemplateSelectVCDelegate?
    
    var sections: [sectionTemplate] = []
    var templates: [keyTemplate] = []
    var keyPropertyToEdit: (key: String, property: Property)?
    
    var templatesListener: ListenerRegistration?
    var templateCategoriesListener: ListenerRegistration?

    var categories: [keyTemplateCategory] = []
    
    var isLoading = false
    var dismissHUD = false

    deinit {
        if let listener = templatesListener {
            listener.remove()
        }
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func cancelTapped(_ sender: AnyObject) {
        if let delegate = delegate {
            delegate.templateSelectionCancelled()
        }
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
        let keyTemplate = sections[indexPath.section].keyTemplates[(indexPath as NSIndexPath).row]
        presentHUDForConnection()
        dbDocumentTemplateWith(documentId: keyTemplate.key).getDocument(completion: { [weak self] (documentSnapshot, error) in
            DispatchQueue.main.async {
                print("Template fetched for selection")
                if let document = documentSnapshot, document.exists {
                    let fullKeyTemplate = (document.documentID, Mapper<Template>().map(JSONObject: document.data())!)
                    if let delegate = self?.delegate {
                        delegate.templateSelected(fullKeyTemplate)
                    }
                }
                dismissHUDForConnection()
            }
        })

        tableView.deselectRow(at: indexPath, animated: true)
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    // MARK: Private Methods
    
    func updateSections() {
        let defaultCategoryTitle = "Uncategorized"
        let keyTemplates = templates
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
    
    func sortTemplates() {
        templates.sort(by: { $0.template.name?.lowercased() ?? "" < $1.template.name?.lowercased() ?? "" } )
    }
    
    func setObservers() {
        
        guard let keyProperty = keyProperty else {
            print("No keyProperty")
            return
        }
        
        let propertyId = keyProperty.key
        var activeTemplateIds: [String] = []
        for templateDict in keyProperty.property.templates {
            if let value = templateDict.value as? NSNumber, value.boolValue == true {
                activeTemplateIds.append(templateDict.key)
            }
        }
        
        
        dbQueryTemplatesWith(propertyId: propertyId).getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                weakSelf.isLoading = false
                
                if let error = error {
                    print("Error getting Templates: \(error)")
                    dismissHUDForConnection()
                    return
                } else if querySnapshot!.documents.count == 0 {
                    print("Templates count: 0")
                    dismissHUDForConnection()
                } else {
                    print("Templates count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
                
                
                weakSelf.templatesListener = dbQueryTemplatesWith(propertyId: propertyId).addSnapshotListener { (querySnapshot, error) in
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
                                
                                if activeTemplateIds.contains(diff.document.documentID) {
                                    let newTemplate = (diff.document.documentID, Mapper<Template>().map(JSONObject: diff.document.data())!)
                                    weakSelf.templates.append(newTemplate)
                                    
                                    weakSelf.sortTemplates()
                                    weakSelf.tableView.reloadData()
                                }
                            } else if (diff.type == .modified) {
                                let changedTemplate: (key: String, template: Template) = (diff.document.documentID, Mapper<Template>().map(JSONObject: diff.document.data())!)
                                
                                if let index = weakSelf.templates.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.templates.remove(at: index)
                                    weakSelf.templates.insert(changedTemplate, at: index)
                                    
                                    weakSelf.sortTemplates()
                                    weakSelf.tableView.reloadData()
                                }
                            } else if (diff.type == .removed) {
                                if let index = weakSelf.templates.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.templates.remove(at: index)
                                    
                                    weakSelf.sortTemplates()
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
}
