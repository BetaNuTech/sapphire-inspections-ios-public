//
//  TeamEditVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/29/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import ImagePicker

class TeamEditVC: UIViewController, UITextFieldDelegate  {
    
    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!
    
    enum SaveState {
        case idle
        case savingTeamData
    }

    @IBOutlet weak var nameField: UITextField!
    
    var teamKey: String?
    var team: Team?
    var newTeam: Team?

    var isNewTeam = false
    
    var saveState = SaveState.idle
    
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
    
    // MARK: Buttons
    
    func addSaveCancelButtons() {
        guard var leftBarButtonItems = navItem?.leftBarButtonItems else {
            return
        }
        
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if !rightBarButtonItems.contains(saveButton) {
            rightBarButtonItems.append(saveButton)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
        
        if !leftBarButtonItems.contains(cancelButton) {
            leftBarButtonItems.append(cancelButton)
            navItem?.leftBarButtonItems = leftBarButtonItems
        }
        
    }
    
    func removeSaveCancelButtons() {
        guard var leftBarButtonItems = navItem?.leftBarButtonItems else {
            return
        }
        
        guard var rightBarButtonItems = navItem?.rightBarButtonItems else {
            return
        }
        
        if let index = rightBarButtonItems.index(of: saveButton) {
            rightBarButtonItems.remove(at: index)
            navItem?.rightBarButtonItems = rightBarButtonItems
        }
        
        if let index = leftBarButtonItems.index(of: cancelButton) {
            leftBarButtonItems.remove(at: index)
            navItem?.leftBarButtonItems = leftBarButtonItems
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let team = team {
            nameField.text = team.name
            newTeam = Team(JSON: team.toJSON())
        } else {
            print("Created new Team object")
            newTeam = Team(JSONString: "{}")
        }
        
        if teamKey == nil {
            print("Created new Team key")
            teamKey = dbCollectionTeams().document().documentID
            isNewTeam = true
        }
        
        removeSaveCancelButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func backgroundTapped(_ sender: AnyObject) {
        view.endEditing(true)
    }
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        view.endEditing(true)
        if !validateFields() {
            return
        }
        
        guard teamKey != nil else {
            self.showMessagePrompt("Error occurred when creating new team key")
            return
        }
        
        guard newTeam != nil else {
            self.showMessagePrompt("Error occurred when creating new team object")
            return
        }
        
        newTeam?.name = nameField.text
        
        SVProgressHUD.show()

        saveState = .savingTeamData
        saveTeam()
    }
    
    
    func sendMessages() {
        guard let newTeam = newTeam else {
            print("Error sending message, missing team data")
            return
        }
        if isNewTeam {
            isNewTeam = false
            Notifications.sendTeamCreation(newTeam: newTeam)
        } else {
            guard let prevTeam = team else {
                print("Error sending message, missing team data")
                return
            }
            if prevTeam.toJSONString() != newTeam.toJSONString() {
                Notifications.sendTeamUpdate(prevTeam: prevTeam, newTeam: newTeam)
            }
        }
        
        close()
    }
    
    func close() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        }
    }
    
    // MARK: UITextField Delegates
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layoutIfNeeded()  // Fixes iOS 9 glitch
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameField:
            view.endEditing(true)
        default:
            view.endEditing(true)
        }
        
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        addSaveCancelButtons()
        
        return true
    }
    
    // MARK: Keyboard
    
//    @objc func keyboardWillShow(_ note: Notification) {
//        let keyboardData = keyboardInfoFromNotification(note)
//        let offsetHeight = keyboardData.endFrame.size.height
//        scrollView.layoutIfNeeded()
//        UIView.animate(withDuration: keyboardData.animationDuration,
//                                   delay: 0,
//                                   options: keyboardData.animationCurve,
//                                   animations: {
//                                    self.scrollViewBottomConstraint.constant = offsetHeight
//                                    self.scrollView.layoutIfNeeded()
//            },
//                                   completion: nil)
//    }
//
//    @objc func keyboardWillHide(_ note: Notification) {
//        let keyboardData = keyboardInfoFromNotification(note)
//        UIView.animate(withDuration: keyboardData.animationDuration,
//                                   delay: 0,
//                                   options: keyboardData.animationCurve,
//                                   animations: {
//                                    self.scrollViewBottomConstraint.constant = 0
//                                    self.scrollView.layoutIfNeeded()
//            }, completion: nil)
//    }
    
    // MARK: Private Methods
    
    func validateFields() -> Bool {
        if nameField.text == "" {
            showMessagePrompt("Team name required")
            return false
        }
        
        return true
    }
    
    func saveTeam() {
        guard let teamKey = teamKey else {
            print("Error saving, missing teamKey")
            return
        }
        guard let team = newTeam else {
            print("Error saving, missing team data")
            return
        }
        databaseUpdateTeam(key: teamKey, team: team, completion: { [weak self] (error) in
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                if error != nil {
                    self?.showMessagePrompt("Error occurred when saving team details")
                } else {
                    self?.sendMessages()
                }
                
                self?.saveState = .idle
                self?.removeSaveCancelButtons()
            }
        })
    }
}
