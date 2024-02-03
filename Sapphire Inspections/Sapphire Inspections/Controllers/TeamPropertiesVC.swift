//
//  TeamPropertiesVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 6/17/19.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import FirebaseFirestore

class TeamPropertiesVC: UIViewController, UITableViewDelegate, UITableViewDataSource, PropertiesVCDelegate {

    @IBOutlet weak var sortHeaderView: SortSectionHeader!
    @IBOutlet weak var tableView: UITableView!
    
    var properties: [KeyProperty] = []
    var keyTeam: KeyTeam?
    var allProperties: [KeyProperty] = []
    var allTeams: [KeyTeam] = []
    var userListener: ListenerRegistration?
    var keyPropertyToView: KeyProperty?
    var keyPropertyToEdit: KeyProperty?

    var currentPropertiesSort: PropertiesSort = .Name // Default
    
    deinit {
        if let listener = userListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        setUserProfileObserver()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let sortStateString = UserDefaults.standard.object(forKey: GlobalConstants.UserDefaults_last_used_properties_sort), let lastSortState = PropertiesSort(rawValue:sortStateString as! String) {
            currentPropertiesSort = lastSortState
        }
        
        updateSortUI()
        updateTeam()
        updateTeamProperties()
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Actions
    
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
        return 1 // Teams & Properties
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Properties
        return properties.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "CategorySectionHeader")
        let header = cell as! CategorySectionHeader
        
        if let teamName = keyTeam?.team.name {
            header.titleLabel.text = teamName
        } else {
            header.titleLabel.text = "Properties for Team"
        }
        
        header.titleLabel.textColor = UIColor.white
        header.titleLabel.textAlignment = .center
        header.background.backgroundColor = GlobalColors.blue

        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "propertyCell") as! PropertyTVCell
        let keyProperty = properties[(indexPath as NSIndexPath).row]
        if userHasPropertyAccess(keyProperty: keyProperty) {
            cell.deficientItemsButton.isEnabled = true
            cell.contentView.alpha = 1
        } else {
            cell.deficientItemsButton.isEnabled = false
            cell.contentView.alpha = 0.5
        }
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        var rowHeight = tableView.frame.size.width * 0.25
        if rowHeight < 140 {
            rowHeight = 140  // min height
        }
        
        return rowHeight
    }

    
    // MARK: UITableView Delegates
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        keyPropertyToView = self.properties[(indexPath as NSIndexPath).row]
        
        if let keyProperty = keyPropertyToView, userHasPropertyAccess(keyProperty: keyProperty) {
            self.performSegue(withIdentifier: "inspectionsFromTeamProperties", sender: self)
        } else {
            keyPropertyToView = nil
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        

        let edit = UITableViewRowAction(style: .normal, title: "Edit") { action, index in
            self.keyPropertyToEdit = self.properties[(indexPath as NSIndexPath).row]
            self.performSegue(withIdentifier: "propertyDetailsFromTeamProperties", sender: self)
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
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let keyProperty = properties[(indexPath as NSIndexPath).row]

        guard userHasPropertyAccess(keyProperty: keyProperty) else {
            return false
        }

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

    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "propertyDetailsFromTeamProperties" {
            if let vc = segue.destination as? PropertyDetailsVC, let keyPropertyToEdit = keyPropertyToEdit {
                vc.propertyKey = keyPropertyToEdit.key
                vc.propertyData = keyPropertyToEdit.property
                
                self.keyPropertyToEdit = nil
            }
        } else if segue.identifier == "inspectionsFromTeamProperties" {
            if let vc = segue.destination as? PropertyProfileVC {
                vc.keyProperty = keyPropertyToView
            }
            keyPropertyToView = nil
        }
    }

    // MARK: Private Methods
    
    func teamsUpdated(keyTeams: [KeyTeam]) {
        allTeams = keyTeams
        updateUI()
    }
    
    func propertiesUpdated(keyProperties: [KeyProperty]) {
        allProperties = keyProperties
        updateUI()
    }
    
    func updateUI() {
        updateTeam()
        updateTeamProperties()
        tableView.reloadData()
    }
    
    func updateTeam() {
        guard let keyTeam = keyTeam else {
            return
        }
        
        let matchedTeams = allTeams.filter { $0.key == keyTeam.key }
        if matchedTeams.count > 0 {
            self.keyTeam = matchedTeams.first
        }
    }
    
    func updateTeamProperties() {
        guard userHasTeamAccess() else {
            properties = []
            return
        }
        
        var teamProperties: [KeyProperty] = []
        for keyProperty in allProperties {
            if isTeamProperty(keyProperty: keyProperty) {
                teamProperties.append(keyProperty)
            }
        }
        
        properties = teamProperties
    }
    
    func isTeamProperty(keyProperty: KeyProperty) -> Bool {
        guard let keyTeam = keyTeam else {
            return false
        }
        
        let matchedProperties = keyTeam.team.properties.filter { $0.key == keyProperty.key }
        
        if matchedProperties.count > 0 {
            return true
        }
        
        return false
    }
    
    func userHasTeamAccess() -> Bool {
        guard let keyTeam = keyTeam else {
            return false
        }
        
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
        }
        
        return false
    }
    
    func userHasPropertyAccess(keyProperty: KeyProperty) -> Bool {
        guard let keyTeam = keyTeam else {
            return false
        }
        
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
            let matchedProperties = profile.properties.keys.filter { $0 == keyProperty.key }
            if matchedProperties.count > 0 {
                return true
            }
        }
        
        return false
    }
    
    func setUserProfileObserver() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    print("Current User Profile Updated, observed by TeamPropertiesVC")
                    self?.updateUI()
                }
            })
        }
    }
        
    
    // MARK: Alerts
    
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
}
