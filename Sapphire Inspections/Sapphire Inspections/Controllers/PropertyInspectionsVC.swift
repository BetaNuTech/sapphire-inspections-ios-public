//
//  PropertyInspectionsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 7/31/16.
//  Copyright © 2016 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import SideMenuController
import SwiftyJSON
import FirebaseFirestore

typealias keyInspection = (key: String, inspection: Inspection)

class PropertyInspectionsVC: UIViewController, TemplateSelectVCDelegate, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    enum Filter: String {
        case off = "Off"
        case completed = "Completed"
        case incomplete = "Incomplete"
        case deficienciesExist = "Deficiencies Exist"
    }
    
//    @IBOutlet weak var bannerPropertyName: UILabel!

//    @IBOutlet weak var propertyImageView: UIImageView!
//    @IBOutlet weak var propertyName: UILabel!
//    @IBOutlet weak var propertyAddress: UILabel!
//    @IBOutlet weak var propertyYearBuilt: UILabel!
//    @IBOutlet weak var propertyNumOfUnits: UILabel!
//    @IBOutlet weak var propertyManagerName: UILabel!
//    @IBOutlet weak var propertyMaintSuperName: UILabel!
//    @IBOutlet weak var propertyLoanType: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var filterLabel: UILabel!
    
    var keyProperty: (key: String, property: Property)?
    var keyTemplateSelected: (key: String, template: Template)?
    var keyInspectionToEdit: keyInspection?
    var keyInspectionToMove: keyInspection?

    var inspections: [keyInspection] = []
    
    var userListener: ListenerRegistration?

    var currentInspectionsSort: InspectionsSort = .CreationDate // Default
    
    var inspectionsForPropertyListener: ListenerRegistration?
    var propertyListener: ListenerRegistration?
    var templateCategoriesListener: ListenerRegistration?

    var categories: [keyTemplateCategory] = []
    
    var filteredInspections: [keyInspection] = []
    var filterString = ""

    var dismissHUD = false
    
    var currentFilter = Filter.off
    
    deinit {
        if let listener = userListener {
            listener.remove()
        }
        
        if let listener = inspectionsForPropertyListener {
            listener.remove()
        }
        if let listener = propertyListener {
            listener.remove()
        }
        if let listener = templateCategoriesListener {
            listener.remove()
        }
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup
        let nib = UINib(nibName: "SortSectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "SortSectionHeader")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 18.0
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 140.0;

        // Defaults
        addButton.isEnabled = false
        
        setObservers()
        
        if let sortStateString = UserDefaults.standard.object(forKey: GlobalConstants.UserDefaults_last_used_inspections_sort), let lastSortState = InspectionsSort(rawValue:sortStateString as! String) {
            currentInspectionsSort = lastSortState
        }
        
        filterButton.tintColor = UIColor.darkText
        filterLabel.text = ""
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        SideMenuController.preferences.interaction.swipingEnabled = true
        
        if pauseUploadingPhotos && FIRConnection.connected() {
            LocalInspectionImages.singleton.startSyncing()
            LocalDeficientImages.singleton.startSyncing()
        }
        pauseUploadingPhotos = false // Reset
        
        updatePropertyDataView()
        
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Deficient Items
    
    func updatePropertyDataView() {
//        var isAdminUser = false
//        var isCorporateUser = false
//        if let profile = currentUserProfile {
//            if let admin = profile.admin {
//                isAdminUser = admin
//            }
//            if let corporate = profile.corporate {
//                isCorporateUser = corporate
//            }
//        }
        
//        if let property = keyProperty?.property {
//            if let urlString = property.logoPhotoURL, let url = URL(string: urlString) {
//                propertyImageView.sd_setImage(with: url)
//                propertyImageView.isHidden = false
//            } else if let urlString = property.bannerPhotoURL, let url = URL(string: urlString) {
//                propertyImageView.sd_setImage(with: url)
//                propertyImageView.isHidden = false
//            }
//            
//            propertyName.text = property.name ?? "No Name"
//            bannerPropertyName.text = property.name ?? "No Name"
//            propertyAddress.text = property.addr1 ?? ""
//            if let addr2 = property.addr2 , addr2 != "" {
//                propertyAddress.text = (propertyAddress.text == "") ? addr2 : propertyAddress.text! + ", " + addr2
//            }
//            if let city = property.city , city != "" {
//                propertyAddress.text = (propertyAddress.text == "") ? city : propertyAddress.text! + ", " + city
//            }
//            if let state = property.state , state != "" {
//                propertyAddress.text = (propertyAddress.text == "") ? state : propertyAddress.text! + ", " + state
//            }
//            if let zip = property.zip , zip != "" {
//                propertyAddress.text = (propertyAddress.text == "") ? zip : propertyAddress.text! + " " + zip
//            }
//            propertyYearBuilt.text = "\(property.year_built ?? 0)"
//            propertyNumOfUnits.text = "\(property.num_of_units ?? 0)"
//            propertyManagerName.text = property.manager_name
//            propertyMaintSuperName.text = property.maint_super_name
//            propertyLoanType.text = property.loan_type
//        }
        
//        numofDeficientItemsRequiringFollowUpLabel.isHidden = !(isAdminUser || isCorporateUser)
//        followUpsLabel.isHidden = !(isAdminUser || isCorporateUser)

//        topConstraintForTable.constant = 68
//        heightConstraintForDeficientItemsBanner.constant = 68
//        if isAdminUser || isCorporateUser {
//            topConstraintForTable.constant = 68
//            heightConstraintForDeficientItemsBanner.constant = 68
//        } else {
//            topConstraintForTable.constant = 44
//            heightConstraintForDeficientItemsBanner.constant = 44
//        }
    }
    
    // MARK: UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterString = searchText
        filterInspections()
        
        tableView.reloadData()
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func filterInspections() {
        if filterString != "" {
            filteredInspections = inspections.filter({  ($0.inspection.inspectorName ?? "").lowercased().contains(filterString.lowercased()) ||
                ($0.inspection.propertyName ?? "").lowercased().contains(filterString.lowercased()) ||
                ($0.inspection.templateName ?? "").lowercased().contains(filterString.lowercased()) ||
                (categoryTitleForKey(categoryKey: $0.inspection.templateCategory ?? "") ?? "uncategorized").lowercased().contains(filterString.lowercased())
            })
        } else {
            filteredInspections = inspections
        }
        
        switch currentFilter {
        case .off:
            break
        case .completed:
            filteredInspections = filteredInspections.filter({
                $0.inspection.itemsCompleted == $0.inspection.totalItems
            })

        case .incomplete:
            filteredInspections = filteredInspections.filter({
                $0.inspection.itemsCompleted < $0.inspection.totalItems
            })

        case .deficienciesExist:
            // Completed, and Deficiencies Exist
            filteredInspections = filteredInspections.filter({
                $0.inspection.deficienciesExist && ($0.inspection.itemsCompleted == $0.inspection.totalItems)
            })
        }
    }
    
    func inspectionsAfterFilter() -> [keyInspection] {
        if filterString != "" || currentFilter != .off {
            return filteredInspections
        } else {
            return inspections
        }
    }
    
    // MARK: Actions
    
    func moveInspection(keyInspection: keyInspection) {
        keyInspectionToMove = keyInspection
        performSegue(withIdentifier: "moveInspection", sender: self)
    }
    
    @IBAction func sortButtonTapped(_ sender: AnyObject) {
        switch currentInspectionsSort {
        case .InspectorName:
            currentInspectionsSort = .CreationDate
        case .CreationDate:
            currentInspectionsSort = .LastUpdateDate
        case .LastUpdateDate:
            currentInspectionsSort = .Score
        case .Score:
            currentInspectionsSort = .Category
        case .Category:
            currentInspectionsSort = .InspectorName
        }
        
        sortInspections()
        
        filterInspections()
        tableView.reloadData()

        // Save current as last used, to be reloaded
        UserDefaults.standard.set(currentInspectionsSort.rawValue, forKey: GlobalConstants.UserDefaults_last_used_inspections_sort)
    }
    
    func sortInspections() {
        if currentInspectionsSort == .Category {
            inspections = sortKeyInspections(inspections, inspectionsSort: .CreationDate)
            inspections = inspections.sorted(by: { categoryTitleForKey(categoryKey: $0.inspection.templateCategory ?? "") ?? "uncategorized" < categoryTitleForKey(categoryKey: $1.inspection.templateCategory ?? "") ?? "uncategorized" })
        } else {
            inspections = sortKeyInspections(inspections, inspectionsSort: currentInspectionsSort)
        }
    }
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        switch currentFilter {
        case .off:
            currentFilter = .completed
            filterButton.tintColor = GlobalColors.blue
            filterLabel.text = currentFilter.rawValue
        case .completed:
            currentFilter = .deficienciesExist
            filterButton.tintColor = GlobalColors.selectedRed
            filterLabel.text = currentFilter.rawValue
        case .deficienciesExist:
            currentFilter = .incomplete
            filterButton.tintColor = GlobalColors.selectedBlack
            filterLabel.text = currentFilter.rawValue
        case .incomplete:
            currentFilter = .off
            filterButton.tintColor = UIColor.darkText
            filterLabel.text = ""
        }
        
        filterInspections()
        tableView.reloadData()
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "templateSelect" {
            if let vc = segue.destination as? TemplateSelectVC {
                vc.delegate = self
                vc.keyProperty = keyProperty
            }
        } else if segue.identifier == "openInspection" {
            if let vc = segue.destination as? InspectionVC {
                if keyInspectionToEdit == nil {
                    vc.readOnly = false
                }

                vc.keyProperty = keyProperty
                vc.keyInspection = keyInspectionToEdit
                vc.keyTemplate = keyTemplateSelected
                keyInspectionToEdit = nil
                keyTemplateSelected = nil
            }
        } else if segue.identifier == "moveInspection" {
            if let vc = segue.destination as? MoveInspectionVC {
                vc.moveFromKeyProperty = keyProperty
                vc.keyInspectionToMove = keyInspectionToMove
            }
        }
    }
    
    // MARK: - TemplateSelectVCDelegate
    
    func templateSelected(_ keyTemplate: (key: String, template: Template)) {
        keyTemplateSelected = keyTemplate
        dismiss(animated: true) {
            // Create New Inspection, based on Template, ready to capture input
            self.performSegue(withIdentifier: "openInspection", sender: self)
        }
    }
    
    func templateSelectionCancelled() {
        dismiss(animated: true) { 
            
        }
    }
    
    // MARK: UITableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return inspectionsAfterFilter().count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "SortSectionHeader")
        let header = cell as! SortSectionHeader
        header.titleLabel.text = "Sorted by \(currentInspectionsSort.rawValue)"
        header.background.backgroundColor = GlobalColors.veryLightBlue
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "inspectionCell") as! InspectionTVCell
        let inspection = inspectionsAfterFilter()[(indexPath as NSIndexPath).row].inspection
        let inspectionKey = inspectionsAfterFilter()[(indexPath as NSIndexPath).row].key
        
        print(inspection.inspectionReportURL ?? "No Inspection URL for \(inspectionKey)")
        
        cell.inspectorName.text = inspection.inspectorName ?? "No Name"
        
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        formatter.timeStyle = .short
        
        if let creationDate = inspection.creationDate {
            let dateString = formatter.string(from: creationDate)
            cell.creationDate.text = dateString
        } else {
            cell.creationDate.text = ""
        }
        if let updatedLastDate = inspection.updatedLastDate {
            let dateString = formatter.string(from: updatedLastDate)
            cell.lastUpdateDate.text = dateString
        } else {
            cell.lastUpdateDate.text = ""
        }
        
        cell.score.text = String(format:"%.1f", inspection.score) + "%"
        if inspection.deficienciesExist {
            cell.score.textColor = GlobalColors.selectedRed
        } else {
            cell.score.textColor = GlobalColors.selectedBlue
        }

        if inspection.itemsCompleted < inspection.totalItems {
            cell.incompletePieView.isHidden = false
            cell.scoreView.isHidden = true
            
            if let circleChart = PNCircleChart(frame: cell.incompletePieView.bounds, total: NSNumber(value: inspection.totalItems), current: NSNumber(value: inspection.itemsCompleted), clockwise: false, shadow: false, shadowColor: GlobalColors.unselectedGrey) {
                circleChart.backgroundColor = UIColor.clear
                circleChart.strokeColor = GlobalColors.selectedBlue
                circleChart.lineWidth = 6.0
                for subview in cell.incompletePieView.subviews {
                    subview.removeFromSuperview()
                }
                cell.incompletePieView.addSubview(circleChart)
                circleChart.stroke()
            }
        } else {
            cell.incompletePieView.isHidden = true
            cell.scoreView.isHidden = false
        }
        
        cell.templateLabel.text = inspection.templateName ?? ""
        if let template = inspection.template, let name = template["name"] as? String {
            cell.templateLabel.text = name
        }
        
        cell.categoryLabel.text = categoryTitleForKey(categoryKey: inspection.templateCategory ?? "") ?? "Uncategorized"

        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        let delete = UITableViewRowAction(style: .normal, title: "Delete") { [weak self] action, index in
            guard let weakSelf = self else {
                return
            }
            let keyInspection = weakSelf.inspectionsAfterFilter()[(indexPath as NSIndexPath).row]
            weakSelf.alertForDeletingInspection(keyInspection)
        }
        delete.backgroundColor = UIColor.red
        
        var userIsAdmin = false
        if let profile = currentUserProfile, !profile.isDisabled {
            userIsAdmin = profile.admin
        }
        
        if !userIsAdmin {
            return [delete]
        }
        
        let move = UITableViewRowAction(style: .normal, title: "Move") { [weak self] action, index in
            guard let weakSelf = self else {
                return
            }
            let keyInspection = weakSelf.inspectionsAfterFilter()[(indexPath as NSIndexPath).row]
            weakSelf.moveInspection(keyInspection: keyInspection)
        }
        move.backgroundColor = UIColor.orange
        
        return [move, delete]
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if let profile = currentUserProfile, !profile.isDisabled {
            return profile.admin
        }
        
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        //        if editingStyle == .Delete {
        //            let propertyKey = properties[indexPath.row].key
        //            alertForDeletingProperty(propertyKey)
        //        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    // TODO: Need to add didselect
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        keyInspectionToEdit = inspectionsAfterFilter()[(indexPath as NSIndexPath).row]
        self.performSegue(withIdentifier: "openInspection", sender: self)        
    }
    
    func categoryTitleForKey(categoryKey: String) -> String? {
        if let index = categories.firstIndex(where: {$0.key == categoryKey}) {
            return categories[index].category.name
        }
        
        return nil
    }

    // MARK: Alerts

    func alertForDeletingInspection(_ keyInspection: keyInspection) {
        let alertController = UIAlertController(title: "Are you sure you want to delete this inspection?", message: nil, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel action"), style: .cancel, handler: { (action) in
            print("Cancel Action")
        })
        let deleteAction = UIAlertAction(title: NSLocalizedString("DELETE", comment: "Delete Action"), style: .destructive, handler: { [weak self] (action) in
            SVProgressHUD.show()
            dbDocumentInspectionWith(documentId: keyInspection.key).delete { (error) in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showMessagePrompt(error!.localizedDescription)
                    } else {
                        if let keyProperty = self?.keyProperty {
                            Notifications.sendPropertyInspectionDeletion(keyProperty: keyProperty, keyInspection: keyInspection)
                        }
                    }
                    SVProgressHUD.dismiss()
                }
            }
        })
        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)
        
        present(alertController, animated: true, completion: {})
    }
    
    // MARK: Private Methods
    
    func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    print("Current User Profile Updated, observed by PropertyInspectionsVC")
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()), !profile.isDisabled {
                            let admin = profile.admin
                            let corporate = profile.corporate
                            var property = false
                            if let keyProperty = weakSelf.keyProperty, let propertyValue = profile.properties[keyProperty.key] as? NSNumber , propertyValue.boolValue {
                                property = true
                            }
                            var team = false
                            if let keyProperty = weakSelf.keyProperty {
                                for teamDict in profile.teams.values {
                                    if let dict = teamDict as? [String : AnyObject] {
                                        if let propertyValue = dict[keyProperty.key] as? NSNumber, propertyValue.boolValue {
                                            team = true
                                            break
                                        }
                                    }
                                }
                            }

                            weakSelf.addButton.isEnabled = admin || corporate || property || team
                            
                        } else {
                            weakSelf.addButton.isEnabled = false
                        }
                        
                        weakSelf.updatePropertyDataView()
                    }
                }
            })
        }
        
        
        guard let propertyId = keyProperty?.key else {
            print("ERROR: No set keyProperty to start observing")
            return
        }

        presentHUDForConnection()
        
        dbQueryInspectionsWith(propertyId: propertyId).getDocuments { [weak self] (querySnapshot, error) in
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                
                if let error = error {
                    dismissHUDForConnection()
                    print("Error getting inspections: \(error)")
                    return
                } else if querySnapshot!.documents.count == 0 {
                    dismissHUDForConnection()
                } else {
                    print("Inspections count: \(querySnapshot!.documents.count)")
                    weakSelf.dismissHUD = true
                }
                
                weakSelf.inspectionsForPropertyListener = dbQueryInspectionsWith(propertyId: propertyId).addSnapshotListener { (querySnapshot, error) in
                    DispatchQueue.main.async {
                        guard let weakSelf = self else {
                            return
                        }
                    
                        guard let snapshot = querySnapshot else {
                            if weakSelf.dismissHUD {
                                dismissHUDForConnection()
                                weakSelf.dismissHUD = false
                            }
                            print("Error fetching dbQueryInspectionsWith snapshots: \(error!)")
                            return
                        }
                        snapshot.documentChanges.forEach { diff in
                            if (diff.type == .added) {
                                if weakSelf.dismissHUD {
                                    dismissHUDForConnection()
                                    weakSelf.dismissHUD = false
                                }
                                
                                let newInspection: keyInspection = (diff.document.documentID, Mapper<Inspection>().map(JSONObject: diff.document.data())!)
                                if let template = newInspection.inspection.template, let name = template["name"] as? String {
                                    newInspection.inspection.templateName = name
                                }
                                newInspection.inspection.template = nil // To save memory
                                weakSelf.inspections.append(newInspection)
                                weakSelf.sortInspections()
                                weakSelf.filterInspections()
                                weakSelf.tableView.reloadData()
                                
                                print("Adding inspection: \(newInspection.key)")
                            }
                            if (diff.type == .modified) {
                                let changedInspection: keyInspection = (diff.document.documentID, Mapper<Inspection>().map(JSONObject: diff.document.data())!)
                                if let template = changedInspection.inspection.template, let name = template["name"] as? String {
                                    changedInspection.inspection.templateName = name
                                }
                                changedInspection.inspection.template = nil
                                
                                if let index = weakSelf.inspections.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.inspections.remove(at: index)
                                    weakSelf.inspections.insert(changedInspection, at: index)
                                    //let indexPathToUpdate = NSIndexPath(forRow: index, inSection: 0)
                                    //self.tableView.reloadRowsAtIndexPaths([indexPathToUpdate], withRowAnimation: .Automatic)
                                    weakSelf.sortInspections()
                                    weakSelf.filterInspections()
                                    weakSelf.tableView.reloadData()
                                }
                            }
                            if (diff.type == .removed) {
                                if let index = weakSelf.inspections.index( where: { $0.key == diff.document.documentID} ) {
                                    weakSelf.inspections.remove(at: index)
                                    weakSelf.filterInspections()
                                    weakSelf.tableView.reloadData()
                                }
                            }
                        }
                    }
                }
            }
        }

//        guard let inspectionsForPropertyRef = inspectionsForPropertyRef else {
//            print("ERROR: inspectionsForPropertyRef is nil")
//            return
//        }
//        inspectionsForPropertyRef.observeSingleEvent(of: .value, with: { [weak self] (snapshot) in
//            DispatchQueue.main.async {
//                guard let weakSelf = self else {
//                    return
//                }
//
//                weakSelf.dismissHUD = false
//                if snapshot.childrenCount == 0 {
//                    dismissHUDForConnection()
//                } else {
//                    weakSelf.dismissHUD = true
//                }
//
//                inspectionsForPropertyRef.observe(.childAdded, with: { [weak self] (snapshot) in
//                    DispatchQueue.main.async {
//                        guard let weakSelf = self else {
//                            return
//                        }
//
//                        if weakSelf.dismissHUD {
//                            dismissHUDForConnection()
//                            weakSelf.dismissHUD = false
//                        }
//
//                        let newInspection: keyInspection = (snapshot.key, Mapper<Inspection>().map(JSONObject: snapshot.value)!)
//                        if let template = newInspection.inspection.template, let name = template["name"] as? String {
//                            newInspection.inspection.templateName = name
//                        }
//                        newInspection.inspection.template = nil // To save memory
//                        weakSelf.inspections.append(newInspection)
//                        weakSelf.sortInspections()
//                        weakSelf.filterInspections()
//                        weakSelf.tableView.reloadData()
//
//                        print("Adding inspection: \(newInspection.key)")
//                    }
//
//                })
//                inspectionsForPropertyRef.observe(.childRemoved, with: { [weak self] (snapshot) in
//                    DispatchQueue.main.async {
//                        guard let weakSelf = self else {
//                            return
//                        }
//
//                        if let index = weakSelf.inspections.index( where: { $0.key == snapshot.key} ) {
//                            weakSelf.inspections.remove(at: index)
//                            weakSelf.filterInspections()
//                            weakSelf.tableView.reloadData()
//                        }
//                    }
//                })
//                inspectionsForPropertyRef.observe(.childChanged, with: { [weak self] (snapshot) in
//                    DispatchQueue.main.async {
//                        guard let weakSelf = self else {
//                            return
//                        }
//
//                        let changedInspection: keyInspection = (snapshot.key, Mapper<Inspection>().map(JSONObject: snapshot.value)!)
//                        if let template = changedInspection.inspection.template, let name = template["name"] as? String {
//                            changedInspection.inspection.templateName = name
//                        }
//                        changedInspection.inspection.template = nil
//
//                        if let index = weakSelf.inspections.index( where: { $0.key == snapshot.key} ) {
//                            weakSelf.inspections.remove(at: index)
//                            weakSelf.inspections.insert(changedInspection, at: index)
//                            //let indexPathToUpdate = NSIndexPath(forRow: index, inSection: 0)
//                            //self.tableView.reloadRowsAtIndexPaths([indexPathToUpdate], withRowAnimation: .Automatic)
//                            weakSelf.sortInspections()
//                            weakSelf.filterInspections()
//                            weakSelf.tableView.reloadData()
//                        }
//                    }
//                })
//            }
//        })
        
        if let propertyKey = keyProperty?.key {
            propertyListener = dbDocumentPropertyWith(documentId: propertyKey).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    
                    if let document = documentSnapshot, document.exists {
                        print("Property Updated")
                        let updatedProperty: (key: String, property: Property) = (document.documentID, Mapper<Property>().map(JSONObject: document.data())!)
                        weakSelf.keyProperty = updatedProperty
                        weakSelf.updatePropertyDataView()
                    } else {
                        print("ERROR: Property Not Found")
                    }
                }
            })
            
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
                        weakSelf.sortInspections()
                        weakSelf.filterInspections()
                        weakSelf.tableView.reloadData()
                    } else if (diff.type == .modified) {
                        let changedCategory: (key: String, category: TemplateCategory) = (diff.document.documentID, Mapper<TemplateCategory>().map(JSONObject: diff.document.data())!)
                        if let index = weakSelf.categories.index( where: { $0.key == diff.document.documentID} ) {
                            weakSelf.categories.remove(at: index)
                            weakSelf.categories.insert(changedCategory, at: index)
                            weakSelf.sortInspections()
                            weakSelf.filterInspections()
                            weakSelf.tableView.reloadData()
                        }
                    } else if (diff.type == .removed) {
                        if let index = weakSelf.categories.index( where: { $0.key == diff.document.documentID} ) {
                            weakSelf.categories.remove(at: index)
                            weakSelf.filterInspections()
                            weakSelf.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }
}


