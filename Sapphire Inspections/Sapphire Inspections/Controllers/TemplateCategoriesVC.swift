//
//  TemplateCategoriesVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 1/11/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore


typealias keyTemplateCategory = (key: String, category: TemplateCategory)

class TemplateCategoriesVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navBar: UINavigationItem!
    
    var categories: [keyTemplateCategory] = []
    var keyCategoryToEdit: (key: String, category: TemplateCategory)?
    var userListener: ListenerRegistration?
    var templateCategoriesListener: ListenerRegistration?

    var dismissHUD = false

    deinit {
        if let listener = userListener {
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
        tableView.estimatedRowHeight = 21.0;
        tableView.keyboardDismissMode = UIScrollView.KeyboardDismissMode.onDrag
        
        setObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addButtonTapped(_ sender: Any) {
        let newKey = dbCollectionTemplateCategories().document().documentID
        let newTemplateCategory = (key: newKey, category: TemplateCategory(JSONString: "{}")!)
        alertForAddingCategory(keyCategory: newTemplateCategory)
    }
    
    // MARK: UITableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell") as! CategoryTVCell
        let category = categories[(indexPath as NSIndexPath).row].category
        
        cell.categoryName.text = category.name ?? "No Name"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .normal, title: "Delete") { [unowned self] action, index in
            if (indexPath as NSIndexPath).row < self.categories.count {
                let keyCategory = self.categories[(indexPath as NSIndexPath).row]
                self.alertForDeleting(keyCategory)
            }

        }
        delete.backgroundColor = UIColor.red
        
        return [delete]
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if let profile = currentUserProfile, !profile.isDisabled {
            return profile.admin || profile.corporate
        }
        
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // This method is for showing slide-to-actions
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let profile = currentUserProfile, !profile.isDisabled {
            if profile.admin || profile.corporate {
                let keyCategory = categories[indexPath.row]
                keyCategoryToEdit = keyCategory
                alertForUpdatingCategoryName(keyCategory: keyCategory)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        // Get the new view controller using segue.destinationViewController.
//        // Pass the selected object to the new view controller.
//    }
    
    // MARK: Private Methods
    
    func sortCategories() {
        categories.sort(by: { $0.category.name?.lowercased() ?? "" < $1.category.name?.lowercased() ?? "" } )
    }
    
    func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    print("Current User Profile Updated, observed by TemplateCategoriesVC")
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
                    print("Template Categories count: 0")
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
                                weakSelf.tableView.reloadData()
                            } else if (diff.type == .modified) {
                                let changedCategory: (key: String, category: TemplateCategory) = (diff.document.documentID, Mapper<TemplateCategory>().map(JSONObject: diff.document.data())!)
                                if let index = weakSelf.categories.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.categories.remove(at: index)
                                    weakSelf.categories.insert(changedCategory, at: index)
                                    weakSelf.sortCategories()
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
    }
    
    // MARK: Alerts
    
    func alertForDeleting(_ keyCategory: (key: String, category: TemplateCategory)) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this category?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            SVProgressHUD.show()
            dbDocumentTemplateCategoryWith(documentId: keyCategory.key).delete { (error) in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showMessagePrompt(error!.localizedDescription)
                    } else {
                        Notifications.sendTemplateCategoryDeletion(templateCategory: keyCategory.category)
                    }
                    
                    SVProgressHUD.dismiss()
                }
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func alertForUpdatingCategoryName(keyCategory: (key: String, category: TemplateCategory)) {
        let alertController = UIAlertController(
            title: "Category Name",
            message: nil,
            preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(
        title: "OK", style: UIAlertAction.Style.default) {
            (action) -> Void in
            
            let name = alertController.textFields!.first!.text ?? ""
            print("You entered \(alertController.textFields!.first!.text ?? "")")
            
            if name != "" {
                let prevTemplateCategory = TemplateCategory(JSON: keyCategory.category.toJSON())
                keyCategory.category.name = name
                dbDocumentTemplateCategoryWith(documentId: keyCategory.key).setData(keyCategory.category.toJSON(), merge: true)
                if let prevTemplateCategory = prevTemplateCategory {
                    if prevTemplateCategory.toJSONString() != keyCategory.category.toJSONString() {
                        Notifications.sendTemplateCategoryUpdate(prevTemplateCategory: prevTemplateCategory, newTemplateCategory: keyCategory.category)
                    }
                }
            }
        }
        
        alertController.addTextField {
            (txtInput) -> Void in
            txtInput.placeholder = "<Enter name here>"
            txtInput.text = keyCategory.category.name
        }
        
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func alertForAddingCategory(keyCategory: (key: String, category: TemplateCategory)) {
        let alertController = UIAlertController(
            title: "Category Name",
            message: nil,
            preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(
        title: "OK", style: UIAlertAction.Style.default) {
            (action) -> Void in
            
            let name = alertController.textFields!.first!.text ?? ""
            print("You entered \(alertController.textFields!.first!.text ?? "")")
            
            if name != "" {
                keyCategory.category.name = name
                dbDocumentTemplateCategoryWith(documentId: keyCategory.key).setData(keyCategory.category.toJSON(), merge: true)
                Notifications.sendTemplateCategoryCreation(newTemplateCategory: keyCategory.category)
            }
        }
        
        alertController.addTextField {
            (txtInput) -> Void in
            txtInput.placeholder = "<Enter name here>"
            txtInput.text = keyCategory.category.name
        }
        
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
}
