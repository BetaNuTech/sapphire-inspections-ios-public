//
//  UsersVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 9/22/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


enum EnumUsersVCSections: String {
    case uncategorized = "Uncategorized"
    case admin = "Admins"
    case corporate = "Corporate"
    case team = "Team"
    case property = "Property"
}

class UsersVC: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    var userIsAdmin = false
    var userIsCorporate = false
    
    var userProfileRefAndHandle: (reference: DatabaseReference?, handle: UInt?)
    var uncategorizedKeyUsers: [(key: String, user: UserProfile)] = []
    var adminKeyUsers: [(key: String, user: UserProfile)] = []
    var corporateKeyUsers: [(key: String, user: UserProfile)] = []
    var teamKeyUsers: [(key: String, user: UserProfile)] = []
    var propertyKeyUsers: [(key: String, user: UserProfile)] = []
    var keyUserToEdit: (key: String, user: UserProfile)?
    
    var sections: [EnumUsersVCSections] = []
    
    var dismissHUD = false

    deinit {
        if let reference = userProfileRefAndHandle.reference, let handle = userProfileRefAndHandle.handle {
            print("User Profile Observer removed by handle in UsersVC")
            reference.removeObserver(withHandle: handle)
        }
        
        usersRef.removeAllObservers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setObservers()
        
        // Setup
        let nib = UINib(nibName: "SortSectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "SortSectionHeader")
        tableView.sectionHeaderHeight = 18.0
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func keyUsersForSection(_ section: EnumUsersVCSections) -> [(key: String, user: UserProfile)] {
        switch section {
        case .uncategorized:
            return uncategorizedKeyUsers
        case .admin:
            return adminKeyUsers
        case .corporate:
            return corporateKeyUsers
        case .team:
            return teamKeyUsers
        case .property:
            return propertyKeyUsers
        }
    }
    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        sections = []
        var sectionCount = 0
        if uncategorizedKeyUsers.count > 0 {
            sectionCount += 1
            sections.append(.uncategorized)
        }
        if adminKeyUsers.count > 0 {
            sectionCount += 1
            sections.append(.admin)
        }
        if corporateKeyUsers.count > 0 {
            sectionCount += 1
            sections.append(.corporate)
        }
        if teamKeyUsers.count > 0 {
            sectionCount += 1
            sections.append(.team)
        }
        if propertyKeyUsers.count > 0 {
            sectionCount += 1
            sections.append(.property)
        }
        
        return sectionCount
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = sections[section]
        let keyUsers = keyUsersForSection(section)
        return keyUsers.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "SortSectionHeader")
        let header = cell as! SortSectionHeader
        
        let section = sections[section]
        header.titleLabel.text = section.rawValue
        switch section {
        case .uncategorized:
            header.background.backgroundColor = GlobalColors.unselectedGrey
        case .admin:
            header.background.backgroundColor = GlobalColors.darkBlue
        case .corporate:
            header.background.backgroundColor = GlobalColors.blue
        case .team:
            header.background.backgroundColor = GlobalColors.lightBlue
        case .property:
            header.background.backgroundColor = GlobalColors.veryLightBlue
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "userCell") as! UserTVCell
        
        let section = sections[(indexPath as NSIndexPath).section]
        let keyUsers = keyUsersForSection(section)
        let user = keyUsers[(indexPath as NSIndexPath).row].user
        cell.userName.text = (user.firstName ?? "") + " " + (user.lastName ?? "")
        if cell.userName.text == " " {
            cell.userName.text = "No Name"
        }
        cell.userEmail.text = user.email ?? "Email missing"
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 61.0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        return UITableView.automaticDimension
    }
    
    
    // MARK: UITableView Delegates
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = sections[(indexPath as NSIndexPath).section]
        let keyUsers = keyUsersForSection(section)
        self.keyUserToEdit = keyUsers[(indexPath as NSIndexPath).row]
        self.performSegue(withIdentifier: "editUserProfile", sender: self)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let disable = UITableViewRowAction(style: .normal, title: "Disable") { action, index in
            let section = self.sections[(indexPath as NSIndexPath).section]
            let keyUsers = self.keyUsersForSection(section)
            let keyUser = keyUsers[(indexPath as NSIndexPath).row]
            self.alertForDisablingUser(keyUser)
        }
        disable.backgroundColor = UIColor.red
        
        return [disable]
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let section = self.sections[(indexPath as NSIndexPath).section]
        let keyUsers = self.keyUsersForSection(section)
        let keyUser = keyUsers[(indexPath as NSIndexPath).row]

        return userIsAdmin && (currentUser!.uid != keyUser.key)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }
    
    // MARK: Private Methods
    
    func addUser(_ keyUser: (key: String, user: UserProfile)) {
        if keyUser.user.isTestUser || keyUser.user.isDeleted || keyUser.user.isDisabled {
            return
        }
        switch userRole(keyUser) {
        case .none:
            uncategorizedKeyUsers.append(keyUser)
            uncategorizedKeyUsers.sort(by: { $0.user.firstName?.lowercased() < $1.user.firstName?.lowercased() })
        case .admin:
            adminKeyUsers.append(keyUser)
            adminKeyUsers.sort(by: { $0.user.firstName?.lowercased() < $1.user.firstName?.lowercased() })
        case .corporate:
            corporateKeyUsers.append(keyUser)
            corporateKeyUsers.sort(by: { $0.user.firstName?.lowercased() < $1.user.firstName?.lowercased() })
        case .team:
            teamKeyUsers.append(keyUser)
            teamKeyUsers.sort(by: { $0.user.firstName?.lowercased() < $1.user.firstName?.lowercased() })
        case .property:
            propertyKeyUsers.append(keyUser)
            propertyKeyUsers.sort(by: { $0.user.firstName?.lowercased() < $1.user.firstName?.lowercased() })
        }
    }
    
    func removeUserByKey(_ key: String) {
        if let index = uncategorizedKeyUsers.index( where: { $0.key == key } ) {
            uncategorizedKeyUsers.remove(at: index)
        } else if let index = adminKeyUsers.index( where: { $0.key == key } ) {
            adminKeyUsers.remove(at: index)
        } else if let index = corporateKeyUsers.index( where: { $0.key == key } ) {
            corporateKeyUsers.remove(at: index)
        } else if let index = teamKeyUsers.index( where: { $0.key == key } ) {
            teamKeyUsers.remove(at: index)
        } else if let index = propertyKeyUsers.index( where: { $0.key == key } ) {
            propertyKeyUsers.remove(at: index)
        }
    }

    func updateUser(_ keyUser: (key: String, user: UserProfile)) {
        removeUserByKey(keyUser.key)
        addUser(keyUser)
    }
    
    func setObservers() {
        if let user = currentUser {
            userProfileRefAndHandle.reference = usersRef.child(user.uid)
            userProfileRefAndHandle.handle = userProfileRefAndHandle.reference!.observe(.value, with: { [weak self] (snapshot) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    print("Current User Profile Updated, observed by UsersVC")
                    if snapshot.exists() {
                        if let profile = Mapper<UserProfile>().map(JSONObject: snapshot.value), !profile.isDisabled {
                            weakSelf.userIsAdmin = profile.admin
                            weakSelf.userIsCorporate = profile.corporate
                        } else {
                            weakSelf.userIsAdmin = false
                            weakSelf.userIsCorporate = false
                        }
                        weakSelf.tableView.reloadData()
                    }
                }
            })
        }
        
        presentHUDForConnection()
        
        usersRef.observeSingleEvent(of: .value, with: { [weak self] (snapshot) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                weakSelf.dismissHUD = false
                if snapshot.childrenCount == 0 {
                    dismissHUDForConnection()
                } else {
                    weakSelf.dismissHUD = true
                }
            
                usersRef.observe(.childAdded, with: { [weak self] (snapshot) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        
                        if weakSelf.dismissHUD {
                            dismissHUDForConnection()
                            weakSelf.dismissHUD = false
                        }
                        
                        let newKeyUser = (snapshot.key, Mapper<UserProfile>().map(JSONObject: snapshot.value)!)
                        weakSelf.addUser(newKeyUser)
                        weakSelf.tableView.reloadData()
                    }
                })
                usersRef.observe(.childRemoved, with: { [weak self] (snapshot) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        
                        weakSelf.removeUserByKey(snapshot.key)
                        weakSelf.tableView.reloadData()
                    }
                })
                usersRef.observe(.childChanged, with: { [weak self] (snapshot) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                        
                        let changedKeyUser = (snapshot.key, Mapper<UserProfile>().map(JSONObject: snapshot.value)!)
                        weakSelf.updateUser(changedKeyUser)
                        weakSelf.tableView.reloadData()
                    }
                })
            }
        })

    }

    // MARK: Alerts
    
    func alertForDisablingUser(_ keyUser: (key: String, user: UserProfile)) {
        let alertController = UIAlertController(title: "Are you sure you want to disable this user?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DISABLE", comment: "Disable Action"), style: .destructive, handler: { [weak self] (action) in
            keyUser.user.isDisabled = true
            usersRef!.child(keyUser.key).updateChildValues(keyUser.user.toJSON())
            self?.tableView.reloadData()
            Notifications.sendUserDisabled(userProfile: keyUser.user)
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editUserProfile" {
            if let vc = segue.destination as? UserProfileVC {
                vc.keyUserToEdit = keyUserToEdit
                vc.userIsAdmin = userIsAdmin
            }
        }
    }
    

}

class UserTVCell: UITableViewCell {
    
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var userEmail: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
