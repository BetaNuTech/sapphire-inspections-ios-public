//
//  UserProfileVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/27/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

protocol UserProfileVCDelegate: class {
    func userProfileUpdated()
    func teamsUpdated(keyTeams: [keyTeam])
    func propertiesUpdated(keyProperties: [keyProperty])
}

enum UserProfileTableMode {
    case teams
    case properties
}

class UserProfileVC: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var userEmail: UILabel!
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var adminSwitch: UISwitch!
    @IBOutlet weak var corporateSwitch: UISwitch!
    @IBOutlet weak var teamCountLabel: UILabel!
    @IBOutlet weak var propertyCountLabel: UILabel!
    
    var userListener: ListenerRegistration?
    var propertiesListener: ListenerRegistration?
    var teamsListener: ListenerRegistration?

    var userIsAdmin = false
    
    var keyUserUnchanged: (key: String, user: UserProfile)?
    var keyUserToEdit: (key: String, user: UserProfile)?
    var keyProperties: [keyProperty] = []
    var keyTeams: [keyTeam] = []

    var dismissHUD = false
    
    weak var delegate: UserProfileVCDelegate?
    
    var userProfileTableMode = UserProfileTableMode.teams
    
    deinit {
        if let listener = userListener {
            listener.remove()
        }

        if let listener = propertiesListener {
            listener.remove()
        }
        if let listener = teamsListener {
            listener.remove()
        }

        guard let keyUser = keyUserToEdit else {
            return
        }
        usersRef.child(keyUser.key).removeAllObservers()
        
        if let keyUserUnchanged = keyUserUnchanged, let keyUserEdited = keyUserToEdit, keyUserUnchanged.user.toJSONString() != keyUserEdited.user.toJSONString() {
            Notifications.sendUserUpdate(prevUserProfile: keyUserUnchanged.user, newUserProfile: keyUserEdited.user, keyProperties: keyProperties, keyTeams: keyTeams)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let keyUser = keyUserToEdit, let userCopy = UserProfile(JSON: keyUser.user.toJSON()) {
            keyUserUnchanged = (key: keyUser.key, user: userCopy)
        }

        updateUI()
        setObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func teamTapped(_ sender: Any) {
        userProfileTableMode = .teams
        performSegue(withIdentifier: "segueUserProfileTable", sender: self)
    }
    
    @IBAction func propertyTapped(_ sender: Any) {
        userProfileTableMode = .properties
        performSegue(withIdentifier: "segueUserProfileTable", sender: self)
    }
    
    func updateUI() {
        if let keyUser = keyUserToEdit {
            userEmail.text = keyUser.user.email ?? "Missing Email Address"
            firstNameField.text = keyUser.user.firstName ?? ""
            lastNameField.text = keyUser.user.lastName ?? ""
            adminSwitch.isOn = keyUser.user.admin
            corporateSwitch.isOn = keyUser.user.corporate
            if adminSwitch.isOn {
                corporateSwitch.isOn = false // Corporate role is a subset of admin
            }
            
            var newAdminValue = false
            if let profile = currentUserProfile, !profile.isDisabled {
                newAdminValue = profile.admin
            }
            userIsAdmin = newAdminValue
            
            if !userIsAdmin {
                firstNameField.isUserInteractionEnabled = false
                lastNameField.isUserInteractionEnabled = false
                adminSwitch.isUserInteractionEnabled = false
                corporateSwitch.isUserInteractionEnabled = false
            } else if currentUser!.uid == keyUser.key {  // If your own profile, don't allow changes to admin/corporate
                firstNameField.isUserInteractionEnabled = true
                lastNameField.isUserInteractionEnabled = true
                adminSwitch.isUserInteractionEnabled = false
                corporateSwitch.isUserInteractionEnabled = false
            } else {
                firstNameField.isUserInteractionEnabled = true
                lastNameField.isUserInteractionEnabled = true
                adminSwitch.isUserInteractionEnabled = true
                corporateSwitch.isUserInteractionEnabled = true
            }
            
            // Set Team count
            var teamCount = 0
            for userTeamKey in keyUser.user.teams.keys {
                let matchedTeams = keyTeams.filter { $0.key == userTeamKey }
                if matchedTeams.count > 0 {
                    teamCount += 1
                }
            }
            teamCountLabel.text = "\(teamCount)"
            
            // Set Property count
            var propertyCount = 0
            for userPropertyKey in keyUser.user.properties.keys {
                let matchedProperties = keyProperties.filter { $0.key == userPropertyKey }
                if matchedProperties.count > 0 {
                    propertyCount += 1
                }
            }
            propertyCountLabel.text = "\(propertyCount)"
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        guard let keyUser = keyUserToEdit else {
            return false
        }
        
        let newString = (textField.text! as NSString).replacingCharacters(in: range, with: string)
        
        // Update keyUser
        if userIsAdmin {
            if textField == firstNameField {
                keyUser.user.firstName = newString
            } else {
                keyUser.user.lastName = newString
            }
            usersRef!.child(keyUser.key).updateChildValues(keyUser.user.toJSON())
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == firstNameField {
            lastNameField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        
        return true
    }
    
    @IBAction func switchValueChanged(_ sender: UISwitch) {
        guard let keyUser = keyUserToEdit else {
            sender.isOn = !sender.isOn
            return
        }
        
        if sender == adminSwitch {
            if sender.isOn {
                corporateSwitch.isOn = false
            }
            
        } else if sender == corporateSwitch {
            if sender.isOn {
                adminSwitch.isOn = false
            }
        }
        
        // Update keyUser
        if userIsAdmin && currentUser!.uid != keyUser.key {
            keyUser.user.admin = adminSwitch.isOn
            keyUser.user.corporate = corporateSwitch.isOn
            usersRef!.child(keyUser.key).updateChildValues(keyUser.user.toJSON())
        } else {
            adminSwitch.isOn = keyUser.user.admin
            corporateSwitch.isOn = keyUser.user.corporate
            if adminSwitch.isOn {
                corporateSwitch.isOn = false // Corporate role is a subset of admin
            }
        }
    }
    
    // MARK: Private Methods
    
    private func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    print("Current User Profile Updated, observed by UserProfileVC")
                    if let document = documentSnapshot, document.exists {
                        if let delegate = self?.delegate {
                            delegate.userProfileUpdated()
                        }
                        self?.updateUI()
                    }
                }
            })
        }
        
        presentHUDForConnection()
        
        dbCollectionProperties().getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting Properties: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    dismissHUDForConnection()
                } else {
                    print("Properties count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
                
                
                weakSelf.propertiesListener = dbCollectionProperties().addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                    
                        guard let snapshot = querySnapshot else {
                            if weakSelf.dismissHUD {
                                dismissHUDForConnection()
                                weakSelf.dismissHUD = false
                            }
                            print("Error fetching dbQueryDeficiencesWith snapshots: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                if weakSelf.dismissHUD {
                                    dismissHUDForConnection()
                                    weakSelf.dismissHUD = false
                                }
                                
                                let newKeyProperty = (diff.document.documentID, Mapper<Property>().map(JSONObject: diff.document.data())!)
                                weakSelf.keyProperties.append(newKeyProperty)
                                weakSelf.keyProperties = sortKeyProperties(weakSelf.keyProperties, propertiesSort: .Name)
                                
                                if let delegate = weakSelf.delegate {
                                    delegate.propertiesUpdated(keyProperties: weakSelf.keyProperties)
                                }
                                weakSelf.updateUI()
                            } else if (diff.type == .modified) {
                                let changedProperty: (key: String, property: Property) = (diff.document.documentID, Mapper<Property>().map(JSONObject: diff.document.data())!)
                                if let index = weakSelf.keyProperties.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.keyProperties.remove(at: index)
                                    weakSelf.keyProperties.insert(changedProperty, at: index)
                                    weakSelf.keyProperties = sortKeyProperties(weakSelf.keyProperties, propertiesSort: .Name)
                                    if let delegate = weakSelf.delegate {
                                        delegate.propertiesUpdated(keyProperties: weakSelf.keyProperties)
                                    }
                                    weakSelf.updateUI()
                                }
                            } else if (diff.type == .removed) {
                                if let index = weakSelf.keyProperties.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.keyProperties.remove(at: index)
                                    if let delegate = weakSelf.delegate {
                                        delegate.propertiesUpdated(keyProperties: weakSelf.keyProperties)
                                    }
                                    weakSelf.updateUI()
                                }
                            }
                        }
                    }
                }
                
                
                weakSelf.teamsListener = dbCollectionTeams().addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                    
                        guard let snapshot = querySnapshot else {
                            print("Error fetching dbCollectionTeams snapshots: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                let newTeam: keyTeam = (diff.document.documentID, Mapper<Team>().map(JSONObject: diff.document.data())!)
                                weakSelf.keyTeams.append(newTeam)
                                weakSelf.keyTeams.sort( by: { $0.team.name?.lowercased() ?? "" < $1.team.name?.lowercased() ?? "" } )
                                if let delegate = weakSelf.delegate {
                                    delegate.teamsUpdated(keyTeams: weakSelf.keyTeams)
                                }
                                weakSelf.updateUI()
                            } else if (diff.type == .modified) {
                                let changedTeam: (key: String, team: Team) = (diff.document.documentID, Mapper<Team>().map(JSONObject: diff.document.data())!)
                                if let index = weakSelf.keyTeams.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.keyTeams.remove(at: index)
                                    weakSelf.keyTeams.insert(changedTeam, at: index)
                                    weakSelf.keyTeams.sort( by: { $0.team.name?.lowercased() ?? "" < $1.team.name?.lowercased() ?? "" } )
                                    if let delegate = weakSelf.delegate {
                                        delegate.teamsUpdated(keyTeams: weakSelf.keyTeams)
                                    }
                                    weakSelf.updateUI()
                                }
                            } else if (diff.type == .removed) {
                                if let index = weakSelf.keyTeams.index( where: { $0.key == diff.document.documentID} ) {
                                     weakSelf.keyTeams.remove(at: index)
                                 }
                                 if let delegate = weakSelf.delegate {
                                     delegate.teamsUpdated(keyTeams: weakSelf.keyTeams)
                                 }
                                 weakSelf.updateUI()
                            }
                        }
                    }
                }
                    
                
            }
            
            
        }
        
        guard let keyUser = keyUserToEdit else {
            return
        }
        usersRef.child(keyUser.key).observe(.childChanged, with: { [weak self] (snapshot) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if weakSelf.keyUserToEdit != nil {
                    var objectJSON = weakSelf.keyUserToEdit!.user.toJSON()
                    if snapshot.value != nil {
                        objectJSON.updateValue(snapshot.value!, forKey: snapshot.key)
                    } else {
                        objectJSON.removeValue(forKey: snapshot.key)
                    }
                    weakSelf.keyUserToEdit!.user = Mapper<UserProfile>().map(JSON: objectJSON)!
                    weakSelf.updateUI()
                }
            }
        })
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? UserProfileTableVC {
            vc.userProfileTableMode = userProfileTableMode
            vc.keyUserToEdit = keyUserToEdit
            delegate = vc
            switch userProfileTableMode {
            case .teams:
                vc.keyTeams = keyTeams
            case .properties:
                vc.keyProperties = keyProperties
            }
        }
    }

}
