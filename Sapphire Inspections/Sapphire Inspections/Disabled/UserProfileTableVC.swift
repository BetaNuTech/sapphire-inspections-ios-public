//
//  UserProfileTableVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 6/13/19.
//  Copyright © 2019 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit

class UserProfileTableVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UserProfileVCDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var userIsAdmin = false
    
    var keyUserToEdit: (key: String, user: UserProfile)?
    var keyProperties: [keyProperty] = []
    var keyTeams: [keyTeam] = []
    
    var userProfileTableMode = UserProfileTableMode.teams
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch userProfileTableMode {
        case .teams:
            title = "Teams"
        case .properties:
            title = "Properties"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func userProfileUpdated() {
        updateUI()
    }
    
    func teamsUpdated(keyTeams: [keyTeam]) {
        self.keyTeams = keyTeams
        updateUI()
    }
    
    func propertiesUpdated(keyProperties: [keyProperty]) {
        self.keyProperties = keyProperties
        updateUI()
    }
    
    func updateUI() {
        if let profile = currentUserProfile, !profile.isDisabled {
            userIsAdmin = profile.admin
        } else {
            userIsAdmin = false
        }
        tableView.reloadData()
        updateSelections()
    }

    // MARK: UITableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch userProfileTableMode {
        case .teams:
            return keyTeams.count
        case .properties:
            return keyProperties.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "selectCell") as! UserProfileSelectTVCell
        
        switch userProfileTableMode {
        case .teams:
            let team = keyTeams[(indexPath as NSIndexPath).row].team
            cell.name.text = team.name ?? "No Name"
        case .properties:
            let property = keyProperties[(indexPath as NSIndexPath).row].property
            cell.name.text = property.name ?? "No Name"
        }
        
        return cell
    }
    
    // MARK: UITableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch userProfileTableMode {
        case .teams:
            let key = keyTeams[(indexPath as NSIndexPath).row].key
            selectTeamKey(key)
        case .properties:
            let key = keyProperties[(indexPath as NSIndexPath).row].key
            selectPropertyKey(key)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        switch userProfileTableMode {
        case .teams:
            let key = keyTeams[(indexPath as NSIndexPath).row].key
            deselectTeamKey(key)
        case .properties:
            let key = keyProperties[(indexPath as NSIndexPath).row].key
            deselectPropertyKey(key)
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 36.0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    // MARK: Private Methods

    func updateSelections() {
        var index = 0
        
        switch userProfileTableMode {
        case .teams:
            for keyTeam in keyTeams {
                let indexPath = IndexPath(row: index, section: 0)
                if isTeamKeySelected(keyTeam.key) {
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                } else {
                    tableView.deselectRow(at: indexPath, animated: false)
                }
                index += 1
            }
        case .properties:
            for keyProperty in keyProperties {
                let indexPath = IndexPath(row: index, section: 0)
                if isPropertyKeySelected(keyProperty.key) {
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                } else {
                    tableView.deselectRow(at: indexPath, animated: false)
                }
                index += 1
            }
        }
    }
    
    func isPropertyKeySelected(_ key: String) -> Bool {
        if let properties = keyUserToEdit?.user.properties {
            for selectedKey in properties.keys {
                if key == selectedKey {
                    return true
                }
            }
        }
        
        return false
    }
    
    func isTeamKeySelected(_ key: String) -> Bool {
        if let teams = keyUserToEdit?.user.teams {
            for selectedKey in teams.keys {
                if key == selectedKey {
                    return true
                }
            }
        }
        
        return false
    }
    
    func selectPropertyKey(_ key: String) {
        guard let keyUser = keyUserToEdit else {
            return
        }
        
        // Update keyUser
        if userIsAdmin {
            presentHUDForConnection()
            keyUser.user.properties[key] = NSNumber(value: true as Bool)
            usersRef!.child(keyUser.key).updateChildValues(keyUser.user.toJSON()) { (error, ref) in
                DispatchQueue.main.async {
                    dismissHUDForConnection()
                }
            }
        } else {
            updateSelections()
        }
    }
    
    func deselectPropertyKey(_ key: String) {
        guard let keyUser = keyUserToEdit else {
            return
        }
        
        // Update keyUser
        if userIsAdmin {
            presentHUDForConnection()
            keyUser.user.properties.removeValue(forKey: key)
            usersRef!.child(keyUser.key).updateChildValues(keyUser.user.toJSON()) { (error, ref) in
                DispatchQueue.main.async {
                    dismissHUDForConnection()
                }
            }
        } else {
            updateSelections()
        }
    }
    
    func selectTeamKey(_ key: String) {
        guard let keyUser = keyUserToEdit else {
            return
        }
        
        // Update keyUser
        if userIsAdmin {
            if let matchedKeyTeam = keyTeams.first(where: { $0.key == key } ) {
                presentHUDForConnection()
                if matchedKeyTeam.team.properties.count > 0 {
                    keyUser.user.teams[key] = matchedKeyTeam.team.properties as AnyObject
                } else {
                    keyUser.user.teams[key] = NSNumber(booleanLiteral: true)
                }
                usersRef!.child(keyUser.key).updateChildValues(keyUser.user.toJSON()) { (error, ref) in
                    DispatchQueue.main.async {
                        dismissHUDForConnection()
                    }
                }
            }
        } else {
            updateSelections()
        }
    }
    
    func deselectTeamKey(_ key: String) {
        guard let keyUser = keyUserToEdit else {
            return
        }
        
        // Update keyUser
        if userIsAdmin {
            presentHUDForConnection()
            keyUser.user.teams.removeValue(forKey: key)
            usersRef!.child(keyUser.key).updateChildValues(keyUser.user.toJSON()) { (error, ref) in
                DispatchQueue.main.async {
                    dismissHUDForConnection()
                }
            }
        } else {
            updateSelections()
        }
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


class UserProfileSelectTVCell: UITableViewCell {
    
    @IBOutlet weak var name: UILabel!
}
