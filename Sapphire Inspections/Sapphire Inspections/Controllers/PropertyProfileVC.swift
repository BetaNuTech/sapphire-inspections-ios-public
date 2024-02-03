//
//  PropertyProfileVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 11/18/21.
//  Copyright © 2021 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import SideMenuController
import SwiftyJSON
import FirebaseFirestore

enum PropertyProfileRow {
    case inspections
    case jobTracking
    case openWorkOrders
    case residents
}

enum PropertyProfileRowTitle: String {
    case inspections = "INSPECTIONS"
    case jobTracking = "JOB TRACKING"
    case openWorkOrders = "OPEN WORK ORDERS"
    case residents = "RESIDENTS"
}

enum PropertyProfileRowDetail: String {
    case inspections = "Add, view, or edit inspections"
    case jobTracking = "Add or manage jobs and their bids"
    case openWorkOrders = "View existing, open work orders"
    case residents = "View existing residents, and their information"
}


class PropertyProfileVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
        
    @IBOutlet weak var bannerPropertyName: UILabel!

    @IBOutlet weak var propertyImageView: UIImageView!
    @IBOutlet weak var propertyName: UILabel!
    @IBOutlet weak var propertyAddress: UILabel!
    @IBOutlet weak var propertyYearBuilt: UILabel!
    @IBOutlet weak var propertyNumOfUnits: UILabel!
    @IBOutlet weak var propertyManagerName: UILabel!
    @IBOutlet weak var propertyMaintSuperName: UILabel!
    @IBOutlet weak var propertyLoanType: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var numOfDeficientItemsLabel: UILabel!
    @IBOutlet weak var numOfDeficientItemsRequiringActionLabel: UILabel!
    @IBOutlet weak var numofDeficientItemsRequiringFollowUpLabel: UILabel!
//    @IBOutlet weak var heightConstraintForDeficientItemsBanner: NSLayoutConstraint!
//    @IBOutlet weak var topConstraintForTable: NSLayoutConstraint!
    
    var keyProperty: (key: String, property: Property)?
    
    var userListener: ListenerRegistration?
    
    var propertyListener: ListenerRegistration?

    var dismissHUD = false
    
    var tableRows: [PropertyProfileRow] = []
    
    
    deinit {
        if let listener = userListener {
            listener.remove()
        }
        
        if let listener = propertyListener {
            listener.remove()
        }
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup
//        let nib = UINib(nibName: "SortSectionHeader", bundle: nil)
//        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "SortSectionHeader")
        tableView.sectionHeaderHeight = 0.0
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 44.0;

        // Defaults
        
        setObservers()
        
        tableRows.append(PropertyProfileRow.inspections)
        tableRows.append(PropertyProfileRow.jobTracking)
        tableRows.append(PropertyProfileRow.openWorkOrders)
        tableRows.append(PropertyProfileRow.residents)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        SideMenuController.preferences.interaction.swipingEnabled = true
                
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
        
        if let property = keyProperty?.property {
            if let urlString = property.logoPhotoURL, let url = URL(string: urlString) {
                propertyImageView.sd_setImage(with: url)
                propertyImageView.isHidden = false
            } else if let urlString = property.bannerPhotoURL, let url = URL(string: urlString) {
                propertyImageView.sd_setImage(with: url)
                propertyImageView.isHidden = false
            }
            
            propertyName.text = property.name ?? "No Name"
            bannerPropertyName.text = property.name ?? "No Name"
            propertyAddress.text = property.addr1 ?? ""
            if let addr2 = property.addr2 , addr2 != "" {
                propertyAddress.text = (propertyAddress.text == "") ? addr2 : propertyAddress.text! + ", " + addr2
            }
            if let city = property.city , city != "" {
                propertyAddress.text = (propertyAddress.text == "") ? city : propertyAddress.text! + ", " + city
            }
            if let state = property.state , state != "" {
                propertyAddress.text = (propertyAddress.text == "") ? state : propertyAddress.text! + ", " + state
            }
            if let zip = property.zip , zip != "" {
                propertyAddress.text = (propertyAddress.text == "") ? zip : propertyAddress.text! + " " + zip
            }
            propertyYearBuilt.text = "\(property.year_built ?? 0)"
            propertyNumOfUnits.text = "\(property.num_of_units ?? 0)"
            propertyManagerName.text = property.manager_name
            propertyMaintSuperName.text = property.maint_super_name
            propertyLoanType.text = property.loan_type
            
            numOfDeficientItemsLabel.text = " \(property.numOfDeficientItems) "
            numOfDeficientItemsRequiringActionLabel.text = " \(property.numOfRequiredActionsForDeficientItems) "
            numofDeficientItemsRequiringFollowUpLabel.text = " \(property.numOfFollowUpActionsForDeficientItems) "
        }
        
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
    
    // MARK: Actions
    
    func openJobs() {
//        showAlertWithOkayButton(title: "Not Yet Supported", message: nil)
//        return
        let inspectionsStoryboard = UIStoryboard(name: "Jobs", bundle: nil)
        if let vc = inspectionsStoryboard.instantiateInitialViewController() as? JobsListVC {
            
            vc.keyProperty = keyProperty
            
            navigationController?.pushViewController(vc, animated: true)
        }

    }
    
    func openWorkOrders() {
        if let propertyCode = keyProperty?.property.code, propertyCode != "" {
            performSegue(withIdentifier: "showPropertyWorkOrders", sender: self)
        } else {
            showMessagePrompt("Property requires Yardi Property Code set.")
        }
    }
    
    func openResidents() {
        if let propertyCode = keyProperty?.property.code, propertyCode != "" {
            performSegue(withIdentifier: "showPropertyResidents", sender: self)
        } else {
            showMessagePrompt("Property requires Yardi Property Code set.")
        }
    }
    
    @IBAction func deficientItemsTapped(_ sender: UIControl) {
        performSegue(withIdentifier: "showDeficientItems", sender: self)
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDeficientItems" {
            if let vc = segue.destination as? DeficientItemsVC {
                vc.keyProperty = keyProperty
            }
        } else if segue.identifier == "showPropertyWorkOrders" {
            if let vc = segue.destination as? PropertyWorkOrdersVC {
                vc.keyProperty = keyProperty
            }
        } else if segue.identifier == "showPropertyResidents" {
           if let vc = segue.destination as? PropertyResidentsVC {
               vc.keyProperty = keyProperty
           }
        } else if segue.identifier == "openInspections" {
            if let vc = segue.destination as? PropertyInspectionsVC {
                vc.keyProperty = keyProperty
            }
         }
    }
    
    // MARK: UITableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableRows.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "propertyProfileCell")!

        switch tableRows[indexPath.row] {
        case .inspections:
            cell.textLabel?.text = PropertyProfileRowTitle.inspections.rawValue
            cell.detailTextLabel?.text = PropertyProfileRowDetail.inspections.rawValue
        case .jobTracking:
            cell.textLabel?.text = PropertyProfileRowTitle.jobTracking.rawValue
            cell.detailTextLabel?.text = PropertyProfileRowDetail.jobTracking.rawValue
        case .openWorkOrders:
            cell.textLabel?.text = PropertyProfileRowTitle.openWorkOrders.rawValue
            cell.detailTextLabel?.text = PropertyProfileRowDetail.openWorkOrders.rawValue
        case .residents:
            cell.textLabel?.text = PropertyProfileRowTitle.residents.rawValue
            cell.detailTextLabel?.text = PropertyProfileRowDetail.residents.rawValue
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch tableRows[indexPath.row] {
        case .inspections:
            performSegue(withIdentifier: "openInspections", sender: self)
        case .jobTracking:
            openJobs()
        case .openWorkOrders:
            openWorkOrders()
        case .residents:
            openResidents()
        }
//        keyInspectionToEdit = inspectionsAfterFilter()[(indexPath as NSIndexPath).row]
//        self.performSegue(withIdentifier: "openInspection", sender: self)
    }
    

    // MARK: Alerts

    
    // MARK: Private Methods
    
    func setObservers() {
        if let user = currentUser {
            presentHUDForConnection()

            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        dismissHUDForConnection()
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

                            
                        }
                        
                        weakSelf.updatePropertyDataView()
                    }
                    
                    dismissHUDForConnection()
                }
            })
        }
        
        
//        guard let propertyId = keyProperty?.key else {
//            print("ERROR: No set keyProperty to start observing")
//            return
//        }

        

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
        
    }
}


