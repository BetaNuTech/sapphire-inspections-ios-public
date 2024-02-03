//
//  TemplateDetailsPageVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 8/5/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class TemplateDetailsPageVC: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    
    static var pageControlHeight: CGFloat = 37  // Always 37?
    
    var isLoading = false
    var newTemplate = false

    // Set by TemplatesVC or unset (new)
    static var keyTemplateToEdit: (key: String, template: Template)? {
        didSet {
            if let keyTemplateToEdit = keyTemplateToEdit {
                TemplateDetailsPageVC.keyTemplate = (keyTemplateToEdit.key, Template(JSONString: keyTemplateToEdit.template.toJSONString()!)!)  // Copy, for editting
            } else {
                TemplateDetailsPageVC.keyTemplate = nil // Reset too
            }
        }
    }
    
    // Working data, not committed until user hits save button
    static var keyTemplate: (key: String, template: Template)?
    static var keySectionsWithKeyItems: KeySectionsWithKeyItems = []
    static var isACopiedTemplate = false
    
    var index = 0
    var identifiers: [String] = ["TemplateDetailsProperties", "TemplateDetailsSections", "TemplateDetailsItems", "TemplateDetailsItemElements", "TemplateDetailsItemValues"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = self
        delegate = self
        
        view.backgroundColor = GlobalColors.veryLightBlue
        
        
        if let startingViewController = self.viewControllerAtIndex(self.index) {
            setViewControllers([startingViewController], direction: UIPageViewController.NavigationDirection.forward, animated: false, completion: nil)
        }
        
        TemplateDetailsPageVC.keySectionsWithKeyItems = [] // Reset

        // Oops, I deleted a template code
//        if let path = Bundle.main.path(forResource: "sapphire-inspections-template-export", ofType: "json")
//        {
//            if let jsonData = try? NSData(contentsOfFile: path, options: .mappedIfSafe)
//            {
//                if let jsonResult: NSDictionary = try! JSONSerialization.jsonObject(with: jsonData as Data, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
//                {
//                    TemplateDetailsPageVC.keyTemplateToEdit?.template = Template(JSON: jsonResult as! [String : Any])!
//                }
//            }
//        }
        
        // Check for existing template, to be edited
        if let keyTemplateToEdit = TemplateDetailsPageVC.keyTemplateToEdit {
            SVProgressHUD.show()
            isLoading = true
            weak var weakSelf = self

            Template.keySectionsWithKeyItems(keyTemplateToEdit.template, completion: { (keySectionWithKeyItems) in
                TemplateDetailsPageVC.keySectionsWithKeyItems = keySectionWithKeyItems
                SVProgressHUD.dismiss()
                weakSelf?.isLoading = false
            })
        // New Template
        } else {
            newTemplate = true
            // Create new templates
            let newKey = dbCollectionTemplates().document().documentID
            TemplateDetailsPageVC.keyTemplate = (newKey, Template(JSONString: "{}")!) // Reset
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        if isLoading {
            return
        }
        
        if let nav = navigationController {
            nav.popViewController(animated: true)
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        if isLoading {
            return
        }
        
        guard let keyTemplate = TemplateDetailsPageVC.keyTemplate else {
            self.showMessagePrompt("Error occurred when saving template, template not found")
            return
        }
        
        self.updateKeyTemplate(keyTemplate)
    }
    
    func viewControllerAtIndex(_ index: Int) -> UIViewController? {
        
        switch index {
        case 0...identifiers.count-1:
            return storyboard!.instantiateViewController(withIdentifier: identifiers[index])

        default:
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        if let identifier = viewController.restorationIdentifier, let index = identifiers.index(of: identifier) {
            //if the index is the end of the array, return nil since we dont want a view controller after the last one
            if index == identifiers.count - 1 {
                return nil
            }
            
            //increment the index to get the viewController after the current index
            self.index = index + 1
            return viewControllerAtIndex(self.index)
        }
        
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        if let identifier = viewController.restorationIdentifier, let index = identifiers.index(of: identifier) {
            //if the index is 0, return nil since we dont want a view controller before the first one
            if index == 0 {
                return nil
            }
            
            //decrement the index to get the viewController before the current one
            self.index = index - 1
            return self.viewControllerAtIndex(self.index)
        }
        
        return nil
    }
    
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return identifiers.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return 0
    }
    
    func updateKeyTemplate(_ keyTemplate: (key: String, template: Template)) {
        var updatedSections: [String: AnyObject] = [:]
        var updatedItems: [String: AnyObject] = [:]
        for keySectionWithItems in TemplateDetailsPageVC.keySectionsWithKeyItems  {
            updatedSections[keySectionWithItems.key] = keySectionWithItems.section.toJSON() as AnyObject?
            for keyItem in keySectionWithItems.keyItems {
                updatedItems[keyItem.key] = keyItem.item.toJSON() as AnyObject?
            }
        }
        
        keyTemplate.template.sections = updatedSections
        keyTemplate.template.items = updatedItems
        
        // Update item version values
        if newTemplate || TemplateDetailsPageVC.isACopiedTemplate {
            keyTemplate.template.resetAllItemVersions()
            print("Template Item versions reset to 0")
        } else if let prevTemplate = TemplateDetailsPageVC.keyTemplateToEdit?.template {
            keyTemplate.template.incrementUpdatedItemVersions(previousTemplateItems: prevTemplate.items)
            print("Template, Updated Item versions incremented")
        }
        
        let json = keyTemplate.template.toJSON()
        SVProgressHUD.show()
        dbDocumentTemplateWith(documentId: keyTemplate.key).setData(json, merge: true) { [weak self] (error) in
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                
                guard let weakSelf = self else {
                    return
                }
                
                if error != nil {
                    weakSelf.showMessagePrompt("Error occurred when saving template details")
                } else {
                    if let nav = weakSelf.navigationController {
                        nav.popViewController(animated: true)
                        
                        if weakSelf.newTemplate {
                            weakSelf.newTemplate = false
                            if let template = TemplateDetailsPageVC.keyTemplate?.template {
                                Notifications.sendTemplateCreation(newTemplate: template)
                            }
                        } else {
                            if let newTemplate = TemplateDetailsPageVC.keyTemplate?.template, let prevTemplate = TemplateDetailsPageVC.keyTemplateToEdit?.template {
                                if prevTemplate.toJSONString() != newTemplate.toJSONString() {
                                    Notifications.sendTemplateUpdate(prevTemplate: prevTemplate, newTemplate: newTemplate)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
