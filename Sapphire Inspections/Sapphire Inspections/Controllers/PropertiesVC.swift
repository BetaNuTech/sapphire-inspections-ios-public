//
//  PropertiesVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/26/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import SwiftyJSON
import Alamofire
import FirebaseFirestore
//import FirebaseDatabaseUI

typealias KeyProperty = (key: String, property: Property)
typealias KeyTeam = (key: String, team: Team)

protocol PropertiesVCDelegate: class {
    func teamsUpdated(keyTeams: [KeyTeam])
    func propertiesUpdated(keyProperties: [KeyProperty])
}

class PropertiesVC: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var sortHeaderView: SortSectionHeader!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    var properties: [KeyProperty] = []
    var teams: [KeyTeam] = []
    var allProperties: [KeyProperty] = []
    var allTeams: [KeyTeam] = []
    var userListener: ListenerRegistration?
    var keyPropertyToEdit: KeyProperty?
    var keyPropertyToView: KeyProperty?
    var keyTeamToEdit: KeyTeam?
    var keyTeamToView: KeyTeam?

    var currentPropertiesSort: PropertiesSort = .Name // Default
    
    var isLoading = false
    var dismissHUD = false
    var areObserversSet = false

    var notifiedOfLatestVersion = false
    
    weak var delegate: PropertiesVCDelegate?

    var propertiesListener: ListenerRegistration?
    var teamsListener: ListenerRegistration?

    
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        isLoading = true
        
        // Setup
        let nib = UINib(nibName: "CategorySectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "CategorySectionHeader")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 30.0

        // Defaults
        addButton.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        if isLoading {
            presentHUDForConnection()
            setUserProfileObserver()
        }
        
        if let sortStateString = UserDefaults.standard.object(forKey: GlobalConstants.UserDefaults_last_used_properties_sort), let lastSortState = PropertiesSort(rawValue:sortStateString as! String) {
            currentPropertiesSort = lastSortState
        }
        updateSortUI()
        
        tableView.reloadData()
        
        checkVersions()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Actions
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        
        let addActionsMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let firstAction = UIAlertAction(title: "Add Property", style: .default, handler: { [weak self] (action) in

            self?.performSegue(withIdentifier: "propertyDetails", sender: self)
        })
        
        let secondAction = UIAlertAction(title: "Add Team", style: .default, handler: { [weak self] (action) in
            
            self?.performSegue(withIdentifier: "teamEdit", sender: self)
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            
        })
        
        addActionsMenu.addAction(firstAction)
        addActionsMenu.addAction(secondAction)
        addActionsMenu.addAction(cancelAction)
        
        // iPad support only
        if let popoverPresentationController = addActionsMenu.popoverPresentationController {
            if let view = sender.value(forKey: "view") as? UIView {
                popoverPresentationController.sourceView = view
                popoverPresentationController.sourceRect = view.bounds
            }
        }
        
        present(addActionsMenu, animated: true, completion: nil)
    }
    

    @IBAction func sortButtonTapped(_ sender: AnyObject) {
        switch currentPropertiesSort {
        case .Name:
            currentPropertiesSort = .City
        case .City:
            currentPropertiesSort = .State
        case .State:
            currentPropertiesSort = .LastInspectionDate
        case .LastInspectionDate:
            currentPropertiesSort = .LastInspectionScore
        case .LastInspectionScore:
            currentPropertiesSort = .Name
        }
        
        self.properties = sortKeyProperties(self.properties, propertiesSort: self.currentPropertiesSort)
        self.tableView.reloadData()
        
        // Save current as last used, to be reloaded
        UserDefaults.standard.set(currentPropertiesSort.rawValue, forKey: GlobalConstants.UserDefaults_last_used_properties_sort)
        
        updateSortUI()
    }
    
    func updateSortUI() {
        sortHeaderView.titleLabel.text = "Sorted by \(currentPropertiesSort.rawValue)"
        sortHeaderView.background.backgroundColor = GlobalColors.veryLightBlue
    }
    
    // MARK: UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2 // Teams & Properties
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Teams
        if section == 0 {
            return teams.count
        }
        
        // Properties
        return properties.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "CategorySectionHeader")
        let header = cell as! CategorySectionHeader
        
        if section == 0 {
            header.titleLabel.text = "TEAMS"
        } else {
            header.titleLabel.text = "PROPERTIES"
        }
        
        header.titleLabel.textColor = UIColor.white
        header.background.backgroundColor = GlobalColors.blue

        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "teamCell") as! TeamTVCell
            let keyTeam = teams[(indexPath as NSIndexPath).row]

            cell.teamName.text = keyTeam.team.name
            
            let counts = deficientCounts(keyTeam: keyTeam)
            
            cell.pendingDICount.text = " \(counts.0) "
            cell.actionsRequiredDICount.text = " \(counts.1) "
            cell.followupRequiredDICount.text = " \(counts.2) "
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "propertyCell") as! PropertyTVCell
            let keyProperty = properties[(indexPath as NSIndexPath).row]
            let property = keyProperty.property
            
            if let urlString = property.photoURL, let url = URL(string: urlString) {
                cell.propertyImageView.sd_setImage(with: url)
            } else {
                cell.propertyImageView.image = UIImage(named: "apartments_icon")
            }
            
            cell.propertyName.text = property.name ?? "No Name"
            cell.propertyAddress12.text = property.addr1 ?? ""
            if let addr2 = property.addr2 , addr2 != "" {
                cell.propertyAddress12.text = (cell.propertyAddress12.text == "") ? addr2 : cell.propertyAddress12.text! + ", " + addr2
            }
            var cityStateZip = (property.city ?? "")
            if let state = property.state , state != "" {
                cityStateZip = (cityStateZip == "") ? state : cityStateZip + ", " + state
            }
            if let zip = property.zip , zip != "" {
                cityStateZip = (cityStateZip == "") ? zip : cityStateZip + " " + zip
            }
            cell.propertyCityStateZip.text = cityStateZip
            
            let score = Int(round(property.lastInspectionScore ?? 0.0))
            var lastInspectionDateString = ""
            if let lastInspectionDate = property.lastInspectionDate {
                let myFormatter = DateFormatter()
                myFormatter.dateFormat = "MMM dd"
                lastInspectionDateString = myFormatter.string(from: lastInspectionDate)
            }
            if property.numOfInspections == 0 {
                cell.propertyInspections.text = "No Inspections"
            } else if property.numOfInspections == 1 {
                cell.propertyInspections.text = "\(property.numOfInspections) Entry [Last: \(score)%, \(lastInspectionDateString)]"
            } else {
                cell.propertyInspections.text = "\(property.numOfInspections) Entries [Last: \(score)%, \(lastInspectionDateString)]"
            }
            cell.pendingDICount.text = " \(property.numOfDeficientItems) "
            cell.actionsRequiredDICount.text = " \(property.numOfRequiredActionsForDeficientItems) "
            cell.followupRequiredDICount.text = " \(property.numOfFollowUpActionsForDeficientItems) "

            cell.deficientItemsClosure = { [weak self] in
                let inspectionsStoryboard = UIStoryboard(name: "Inspections", bundle: nil)
                if let vc = inspectionsStoryboard.instantiateViewController(withIdentifier: "deficientItemsView") as? DeficientItemsVC {
                    
                    vc.keyProperty = keyProperty
                    
                    self?.navigationController?.pushViewController(vc, animated: true)
                }
            }
            
            return cell
        }
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        // TEAMS
        if indexPath.section == 0 {
            let edit = UITableViewRowAction(style: .normal, title: "Edit") { action, index in
                self.keyTeamToEdit = self.teams[(indexPath as NSIndexPath).row]
                self.performSegue(withIdentifier: "teamEdit", sender: self)
            }
            edit.backgroundColor = GlobalColors.darkBlue
            
            // Admins can only delete Teams
            if let profile = currentUserProfile, !profile.isDisabled, profile.admin == true {
                let delete = UITableViewRowAction(style: .normal, title: "Delete") { action, index in
                    let keyTeam = self.teams[(indexPath as NSIndexPath).row]
                    self.alertForDeletingTeam(keyTeam)
                }
                delete.backgroundColor = UIColor.red
            
                return [delete, edit]
            }
            
            return [edit]
            
        // PROPERTIES
        } else {
            let edit = UITableViewRowAction(style: .normal, title: "Edit") { action, index in
                self.keyPropertyToEdit = self.properties[(indexPath as NSIndexPath).row]
                self.performSegue(withIdentifier: "propertyDetails", sender: self)
            }
            edit.backgroundColor = GlobalColors.darkBlue
            
            // Admins can only delete Properties
            if let profile = currentUserProfile, !profile.isDisabled, profile.admin == true {
                let delete = UITableViewRowAction(style: .normal, title: "Delete") { action, index in
                    let keyProperty = self.properties[(indexPath as NSIndexPath).row]
                    self.alertForDeletingProperty(keyProperty)
                }
                delete.backgroundColor = UIColor.red
                
                return [delete, edit]
            }
            
            return [edit]
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if let profile = currentUserProfile, !profile.isDisabled {
            if profile.admin == true {
                return true
            }
            if profile.corporate == true {
                return true
            }
        }
        
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
//        if editingStyle == .Delete {
//            let propertyKey = properties[indexPath.row].key
//            alertForDeletingProperty(propertyKey)
//        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        // TEAMS
        if indexPath.section == 0 {
            return 100
        }
        
        var rowHeight = tableView.frame.size.width * 0.25
        if rowHeight < 140 {
            rowHeight = 140  // min height
        }
        
        return rowHeight
    }

    
    // MARK: UITableView Delegates
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            self.keyTeamToView = self.teams[(indexPath as NSIndexPath).row]
            self.performSegue(withIdentifier: "showTeamProperties", sender: self)
        } else {
            self.keyPropertyToView = self.properties[(indexPath as NSIndexPath).row]
            self.performSegue(withIdentifier: "inspections", sender: self)
        }
    }
    
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
        if segue.identifier == "propertyDetails" {
            if let vc = segue.destination as? PropertyDetailsVC, let keyPropertyToEdit = keyPropertyToEdit {
                vc.propertyKey = keyPropertyToEdit.key
                vc.propertyData = keyPropertyToEdit.property
                
                self.keyPropertyToEdit = nil
            }
        } else if segue.identifier == "inspections" {
            if let vc = segue.destination as? PropertyProfileVC {
                vc.keyProperty = keyPropertyToView
            }
            keyPropertyToView = nil
        } else if segue.identifier == "teamEdit" {
            if let vc = segue.destination as? TeamEditVC, let keyTeamToEdit = keyTeamToEdit {
                vc.teamKey = keyTeamToEdit.key
                vc.team = keyTeamToEdit.team
                
                self.keyTeamToEdit = nil
            }
        } else if segue.identifier == "showTeamProperties" {
            if let vc = segue.destination as? TeamPropertiesVC {
                vc.keyTeam = keyTeamToView
                vc.allProperties = allProperties
                vc.allTeams = allTeams
                delegate = vc
            }
            keyTeamToView = nil
        }
    }

    // MARK: Private Methods
    
    func deficientCounts(keyTeam: KeyTeam) -> (UInt, UInt, UInt) {
        let fullTeamAccess = hasFullTeamAccess(teamKey: keyTeam.key)
        var sumOfPendingDeficientItems: UInt = 0
        var sumOfActionsRequiredDeficientItems: UInt = 0
        var sumOfFollowUpDeficientItems: UInt = 0
        
        for teamPropertyKey in keyTeam.team.properties.keys {
            var matchedPropertiesInTeam: [KeyProperty] = []
            if fullTeamAccess {
                matchedPropertiesInTeam = allProperties.filter { $0.key == teamPropertyKey }
            } else {
                matchedPropertiesInTeam = properties.filter { $0.key == teamPropertyKey }
            }
            if matchedPropertiesInTeam.count > 0 {
                let property = matchedPropertiesInTeam[0].property
                sumOfPendingDeficientItems += property.numOfDeficientItems
                sumOfActionsRequiredDeficientItems += property.numOfRequiredActionsForDeficientItems
                sumOfFollowUpDeficientItems += property.numOfFollowUpActionsForDeficientItems
            }
        }
        
        return (sumOfPendingDeficientItems, sumOfActionsRequiredDeficientItems, sumOfFollowUpDeficientItems)
    }
    
    func updateUserTeams() {
        var userTeams: [KeyTeam] = []
        for keyTeam in allTeams {
            if canAddTeam(keyTeam: keyTeam) {
                userTeams.append(keyTeam)
            }
        }
        
        teams = userTeams
    }
    
    func updateUserProperties() {
        var userProperties: [KeyProperty] = []
        for keyProperty in allProperties {
            if canAddProperty(keyProperty: keyProperty) {
                userProperties.append(keyProperty)
            }
        }
        
        properties = userProperties
    }
    
    func canAddProperty(keyProperty: (key: String, property: Property)) -> Bool {
        if let profile = currentUserProfile, !profile.isDisabled {
            if profile.admin {
                return true
            }
            if profile.corporate, profile.teams.count == 0, profile.properties.count == 0 {
                return true
            }

            return (profile.properties[keyProperty.key] as? NSNumber)?.boolValue ?? false
        }
        
        return false
    }
    
    func canAddTeam(keyTeam: KeyTeam) -> Bool {
        if let profile = currentUserProfile, !profile.isDisabled {
            if profile.admin {
                return true
            }
            if profile.corporate, profile.teams.count == 0, profile.properties.count == 0 {
                return true
            }
            // Team match?
            let matchedTeams = profile.teams.filter { $0.key == keyTeam.key }
            if matchedTeams.count > 0 {
                return true
            }
            // User Property part of Team?
            for keyProperty in profile.properties {
                let matchedPropertiesInTeam = keyTeam.team.properties.keys.filter { $0 == keyProperty.key }
                if matchedPropertiesInTeam.count > 0 {
                    return true
                }
            }
            
            
            // TODO: Add support for Team user, who is property level
//            return (profile.properties[keyProperty.key] as? NSNumber)?.boolValue ?? false
        }
        
        return false
    }
    
    func hasFullTeamAccess(teamKey: String) -> Bool {
        if let profile = currentUserProfile, !profile.isDisabled {
            if profile.admin {
                return true
            }
            if profile.corporate, profile.teams.count == 0, profile.properties.count == 0 {
                return true
            }
            // Team match?
            let matchedTeams = profile.teams.filter { $0.key == teamKey }
            if matchedTeams.count > 0 {
                return true
            }
        }
        
        return false
    }
    
    func setUserProfileObserver() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    print("Current User Profile Updated, observed by PropertiesVC")
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()), !profile.isDisabled {
                            weakSelf.addButton.isEnabled = profile.admin
                        } else {
                            weakSelf.addButton.isEnabled = false
                        }
                        
                        if currentUserProfile?.firstName == "" {
                            weakSelf.showMessagePrompt("Please update your profile, from the side panel")
                        }
                        
                        if !weakSelf.areObserversSet {
                            weakSelf.setObservers()
                            weakSelf.areObserversSet = true
                        }
                    }
                    weakSelf.updateUserProperties()
                    weakSelf.updateUserTeams()
                    weakSelf.tableView.reloadData()
                }
            })
        }
    }
    
    func setObservers() {
        dbCollectionProperties().getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                weakSelf.isLoading = false
                
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
                            print("Error fetching dbCollectionProperties snapshots: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                if weakSelf.dismissHUD {
                                    dismissHUDForConnection()
                                    weakSelf.dismissHUD = false
                                }
                                
                                let newProperty: (key: String, property: Property) = (diff.document.documentID, Mapper<Property>().map(JSONObject: diff.document.data())!)
                                weakSelf.allProperties.append(newProperty)
                                weakSelf.allProperties = sortKeyProperties(weakSelf.allProperties, propertiesSort: weakSelf.currentPropertiesSort)
                                weakSelf.updateUserProperties()
                                weakSelf.tableView.reloadData()
                                
                                if let delegate = weakSelf.delegate {
                                    delegate.propertiesUpdated(keyProperties: weakSelf.allProperties)
                                }
                            } else if (diff.type == .modified) {
                                let changedProperty: (key: String, property: Property) = (diff.document.documentID, Mapper<Property>().map(JSONObject: diff.document.data())!)
                                if let index = weakSelf.allProperties.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.allProperties.remove(at: index)
                                    weakSelf.allProperties.insert(changedProperty, at: index)
                                    weakSelf.allProperties = sortKeyProperties(weakSelf.allProperties, propertiesSort: weakSelf.currentPropertiesSort)
                                    weakSelf.updateUserProperties()
                                    weakSelf.tableView.reloadData()
                                    
                                    if let delegate = weakSelf.delegate {
                                        delegate.propertiesUpdated(keyProperties: weakSelf.allProperties)
                                    }
                                }
                            } else if (diff.type == .removed) {
                                if let index = weakSelf.allProperties.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.allProperties.remove(at: index)
                                    weakSelf.updateUserProperties()
                                    weakSelf.tableView.reloadData()
                                    
                                    if let delegate = weakSelf.delegate {
                                        delegate.propertiesUpdated(keyProperties: weakSelf.allProperties)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        
        teamsListener = dbCollectionTeams().addSnapshotListener { [weak self] (querySnapshot, error) in
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
                        let newTeam: KeyTeam = (diff.document.documentID, Mapper<Team>().map(JSONObject: diff.document.data())!)
                        weakSelf.allTeams.append(newTeam)
                        weakSelf.allTeams.sort( by: { $0.team.name?.lowercased() ?? "" < $1.team.name?.lowercased() ?? "" } )
                        weakSelf.updateUserTeams()
                        weakSelf.tableView.reloadData()
                        
                        if let delegate = weakSelf.delegate {
                            delegate.teamsUpdated(keyTeams: weakSelf.allTeams)
                        }
                    } else if (diff.type == .modified) {
                        let changedTeam: (key: String, team: Team) = (diff.document.documentID, Mapper<Team>().map(JSONObject: diff.document.data())!)
                        if let index = weakSelf.allTeams.index( where: { $0.key == diff.document.documentID} ) {
                            weakSelf.allTeams.remove(at: index)
                            weakSelf.allTeams.insert(changedTeam, at: index)
                            weakSelf.allTeams.sort( by: { $0.team.name?.lowercased() ?? "" < $1.team.name?.lowercased() ?? "" } )
                            weakSelf.updateUserTeams()
                            weakSelf.tableView.reloadData()
                            
                            if let delegate = weakSelf.delegate {
                                delegate.teamsUpdated(keyTeams: weakSelf.allTeams)
                            }
                        }
                    } else if (diff.type == .removed) {
                        if let index = weakSelf.allTeams.index( where: { $0.key == diff.document.documentID} ) {
                            weakSelf.allTeams.remove(at: index)
                            weakSelf.updateUserTeams()
                            weakSelf.tableView.reloadData()
                            
                            if let delegate = weakSelf.delegate {
                                delegate.teamsUpdated(keyTeams: weakSelf.allTeams)
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    // MARK: Alerts
    
    func alertForDeletingTeam(_ keyTeam: KeyTeam) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this team?", message: "NOTE: This action will also delete all entries assoicated with this team", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            SVProgressHUD.show()
            dbDocumentTeamWith(documentId: keyTeam.key).delete { (error) in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showMessagePrompt(error!.localizedDescription)
                    } else {
                        Notifications.sendTeamDeletion(team: keyTeam.team)
                    }
                    
                    SVProgressHUD.dismiss()
                }
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func alertForDeletingProperty(_ keyProperty: (key: String, property: Property)) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this property?", message: "NOTE: This action will also delete all entries assoicated with this property", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            SVProgressHUD.show()
            dbDocumentPropertyWith(documentId: keyProperty.key).delete { (error) in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showMessagePrompt(error!.localizedDescription)
                    } else {
                        Notifications.sendPropertyDeletion(property: keyProperty.property)
                    }
                    if let filename = keyProperty.property.photoName {
                        storagePropertyImagesRef.child(filename).delete(completion: { (error) in
                        })
                    }
                    if let filename = keyProperty.property.bannerPhotoName {
                        storagePropertyImagesRef.child(filename).delete(completion: { (error) in
                        })
                    }
                    if let filename = keyProperty.property.logoName {
                        storagePropertyImagesRef.child(filename).delete(completion: { (error) in
                        })
                    }
                    
                    SVProgressHUD.dismiss()
                }
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    func checkVersions() {
        guard let user = currentUser else {
            print("ERROR: no user for checkVersions")
            return
        }
        
        
        user.getIDToken { [weak self] (token, error) in
            guard let token = token else {
                print("ERROR: no token for checkVersions")
                return
            }
            
            let headers: HTTPHeaders = [
                "Authorization": "FB-JWT \(token)",
                "Content-Type": "application/json"
            ]
            
            AF.request(versionsURLString, headers: headers).responseJSON { [weak self] response in
                debugPrint(response)
                
                guard let weakSelf = self else {
                    return
                }
                
                if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                    guard let data = response.data else {
                        print("ERROR: checkVersions() - no data")
                        return
                    }
                    
                    let json = JSON(data)
                    
                    if let iOSVersion = json["ios"].string {
                        print("Latest iOS Version: \(iOSVersion)")
                        latestVersionAvailable = iOSVersion
                        requiredVersionForcesUpdate = false
                        if let requiredVersion = json["required_ios_version"].string {
                            print("Required iOS Version: \(requiredVersion)")
                            requiredVersionForcesUpdate = !doesCurrentVersionMeetRequirement(requiredVersion: requiredVersion)
                        }
                        if requiredVersionForcesUpdate ||
                            !weakSelf.notifiedOfLatestVersion && !doesCurrentVersionMeetRequirement(requiredVersion: iOSVersion)  {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                                guard let weakSelf = self else {
                                    return
                                }
                                
                                if requiredVersionForcesUpdate {
                                    do {
                                        try Auth.auth().signOut()
                                    } catch {
                                        print("SignOut failed")
                                    }
                                } else {
                                    let title = "Version \(latestVersionAvailable) Available"
                                    let message = "Please install the latest version."
                                    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                                    let okAction = UIAlertAction(title: "OK", style: .default) { action in
                                        let urlString = webAppBaseURL + "/ios"
                                        guard let url = URL(string: urlString) else {
                                            print("ERROR: URL malformed")
                                            return
                                        }
                                        
                                        if #available(iOS 10.0, *) {
                                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                        } else {
                                            UIApplication.shared.openURL(url)
                                        }
                                    }
                                    let cancelAction = UIAlertAction(title: "CANCEL", style: .cancel) { action in
                                    }
                                    alertController.addAction(okAction)
                                    alertController.addAction(cancelAction)
                                    weakSelf.present(alertController, animated: false, completion: nil)
                                    weakSelf.notifiedOfLatestVersion = true
                                }
                            }
                        }
                    }
                } else {
                   let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                   print("ERROR: checkVersions() - \(errorMessage ?? "")")
                }
            } // AF.request
        } // user.getIDToken
    } // checkVersions()
    
}
