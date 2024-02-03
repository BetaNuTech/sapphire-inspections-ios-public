//
//  ItemNotesVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/3/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

protocol ItemNotesVCDelegate: class {
    func itemNotesUpdated(item: TemplateItem, action: String)
}

class ItemNotesVC: UIViewController, UITextViewDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var textViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var itemTitle: UILabel!
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    
    var item: TemplateItem?
    var mainInput = false
    var readOnly = true
    weak var delegate: ItemNotesVCDelegate?
    
    var itemHasUpdates = false

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(PropertyDetailsVC.keyboardWillShow(_:)),
                                                         name: UIResponder.keyboardWillShowNotification,
                                                         object: nil)
        NotificationCenter.default.addObserver(self,
                                                         selector: #selector(PropertyDetailsVC.keyboardWillHide(_:)),
                                                         name: UIResponder.keyboardWillHideNotification,
                                                         object: nil)
        if let item = item {
            itemTitle.text = item.title
            if mainInput {
                title = "Description"
                navItem.title = "Description"
                textView.text = item.mainInputNotes
            } else {
                title = "Notes"
                navItem.title = "Notes"
                textView.text = item.inspectorNotes
            }
        }
        
        textView.isUserInteractionEnabled = !readOnly
        
        if !readOnly {
            textView.becomeFirstResponder()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateNavButtons()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        textView.resignFirstResponder()
        
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateNavButtons() {
        if itemHasUpdates {
            addDoneButton()
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

    
    // MARK: - TextView Delegate
    
    func textViewDidChange(_ textView: UITextView) {
        if let item = item {
            if mainInput {
                item.mainInputNotes = textView.text
                delegate?.itemNotesUpdated(item: item, action: "updated main notes")
            } else {
                item.inspectorNotes = textView.text
                delegate?.itemNotesUpdated(item: item, action: "updated notes")
            }
            
            itemHasUpdates = true
            updateNavButtons()
        }
    }

    // MARK: Keyboard
    
    @objc func keyboardWillShow(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        let offsetHeight = keyboardData.endFrame.size.height
        textView.layoutIfNeeded()
        UIView.animate(withDuration: keyboardData.animationDuration,
                                   delay: 0,
                                   options: keyboardData.animationCurve,
                                   animations: {
                                    self.textViewBottomConstraint.constant = offsetHeight
                                    self.textView.layoutIfNeeded()
            },
                                   completion: nil)
    }
    
    @objc func keyboardWillHide(_ note: Notification) {
        let keyboardData = keyboardInfoFromNotification(note)
        textView.layoutIfNeeded()
        UIView.animate(withDuration: keyboardData.animationDuration,
                                   delay: 0,
                                   options: keyboardData.animationCurve,
                                   animations: {
                                    self.textViewBottomConstraint.constant = 0
                                    self.textView.layoutIfNeeded()
            }, completion: nil)
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
