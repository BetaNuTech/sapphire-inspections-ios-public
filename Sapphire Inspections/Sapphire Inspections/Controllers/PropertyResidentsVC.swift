//
//  PropertyResidentsVC.swift
//  Sapphire Inspections
//
//  Created by Stu Carney on 3/23/20.
//  Copyright © 2020 Beta Nu Technologies LLC. All rights reserved.
//

import UIKit
import Alamofire
import SWXMLHash
import MessageUI
import SwiftyJSON
import FirebaseFirestore

enum PropertyResidentsSort: String {
    case unitID = "unitID"
    case residentID = "residentID"
    case residentFirstName = "residentFirstName"
    case residentLastName = "residentLastName"
    case status = "status"
}

enum PropertyResidentsFilter: String {
    case all = "All"
    case current = "Current"
    case future = "Future"
    case eviction = "Eviction"
    case notice = "Notice"
    case vacant = "Vacant"
}

struct YardiResident {
    var ResidentID: String?
    var Status: String?
    var YardiStatus: String?
    var FirstName: String?
    var MiddleName: String?
    var LastName: String?
    var Email: String?
    var MobilePhone: String?
    var HomePhone: String?
    var OfficePhone: String?
    var UnitID: String?
    var LeaseFromDate: String?
    var LeaseToDate: String?
    var ActualMoveIn: String?
    var UnitSqFt: String?
    var OtherOccupants: [YardiRoommate]?
}

struct CobaltCollectionsByTenant {
    var tenantCode: String?
    var totalCharges: Double?
    var totalOwed: Double?
    var paymentPlan: Bool?
    var eviction: Bool?
    var lastNote: String?
    var paymentPlanDelinquent: Bool?
    var lastNoteUpdatedAt: Date?
}

struct ResidentWithCollections {
    var resident: YardiResident
    var collections: CobaltCollectionsByTenant
}

let IgnoredResidentYardiStatuses = [
    "past",
    "applicant",
    "denied",
    "canceled"
]

struct YardiRoommate {
    var ResidentID: String?
    var RoommateID: String?
    var Relationship: String?
    var FirstName: String?
    var MiddleName: String?
    var LastName: String?
    var Email: String?
    var MobilePhone: String?
    var HomePhone: String?
    var OfficePhone: String?
}

struct ResidentAction {
    var order: Int
    var action: ResidentActionType
    var value: String
}

enum ResidentActionType {
    case call
    case email
}

class PropertyResidentsVC: UIViewController, UITableViewDelegate, UITableViewDataSource, MFMailComposeViewControllerDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sortLabel: UILabel!
    @IBOutlet weak var filterButton: UIBarButtonItem!
    
    var adminCorporateUser = false
    
    var keyProperty: (key: String, property: Property)?
    
    var userListener: ListenerRegistration?

    var residents: [YardiResident] = []
    var collectionsByTenant: [String: CobaltCollectionsByTenant] = [:]
    var residentsWithCollections: [ResidentWithCollections] = []
    var collectionsByTenantTimestamp: Date?

    var filterString = ""
    var filteredResidents: [YardiResident] = []
    
    var residentsFilteredAndSorted: [YardiResident] = []
    
    var dismissHUD = false
        
    var currentSort = PropertyResidentsSort.unitID
        
    var currentFilter = PropertyResidentsFilter.all

    deinit {
        if let listener = userListener {
            listener.remove()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let code = keyProperty?.property.code {
            self.title = code.uppercased() + " Residents"
        }

        // Defaults
        let nib = UINib(nibName: "PropertySectionHeader", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "PropertySectionHeader")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        tableView.sectionHeaderHeight = 36.0
        tableView.sectionFooterHeight = 0.0
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.estimatedRowHeight = 100.0;
        
        // UITable Setup

        setObservers()
        
        getCurrentResidentsFromFirebase()
        
//        getCurrentResidents()
//        getCollectionsByTenant()
        
        filterButton.title = currentFilter.rawValue
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateResidents()
        updateSortLabel()
    }
    
    // MARK: Actions
    
    @IBAction func filterButtonTapped(_ sender: UIBarButtonItem) {
        switch currentFilter {
            case .all:
                currentFilter = .current
            case .current:
                currentFilter = .future
            case .future:
                currentFilter = .eviction
            case .eviction:
                currentFilter = .notice
            case .notice:
                currentFilter = .vacant
            case .vacant:
                currentFilter = .all
        }
        
        filterButton.title = currentFilter.rawValue

        updateResidents()
    }
    

    @IBAction func sortButtonTapped(_ sender: UIBarButtonItem) {
        // Change sorting
        switch currentSort {
            case .unitID:
                currentSort = .residentID
            case .residentID:
                currentSort = .residentFirstName
            case .residentFirstName:
                currentSort = .residentLastName
            case .residentLastName:
                currentSort = .status
            case .status:
                currentSort = .unitID
        }

        // Update sort label
        updateSortLabel()

        // Reload Data
        updateResidents()
    }
    
    func updateSortLabel() {
        switch currentSort {
            case .unitID:
                sortLabel.text = "Sorted by Unit"
            case .residentID:
                sortLabel.text = "Sorted by Resident ID"
            case .residentFirstName:
                sortLabel.text = "Sorted by Resident First Name"
            case .residentLastName:
                sortLabel.text = "Sorted by Resident Last Name"
            case .status:
                sortLabel.text = "Sorted by Current Status"
        }
    }
    
    // MARK: Get Residents and Collections (Firebase)
    
    fileprivate func getCurrentResidentsFromFirebase() {
        guard let keyProperty = keyProperty else {
            print("ERROR: keyProperty Data is nil")
            return
        }
        
        if let user = currentUser {
            user.getIDToken { [weak self] (token, error) in
                if let token = token {
                    let headers: HTTPHeaders = [
                        "Authorization": "FB-JWT \(token)",
                        "Content-Type": "application/json"
                    ]
                    
//                    let parameters: Parameters = [:]
                    
                    presentHUDForConnection()
                    AF.request(getYardiResidentsURLString(propertyId: keyProperty.key), method: .get, headers: headers).responseJSON { [weak self] response in
                        DispatchQueue.main.async {
                            // debugPrint(response)
                            if let statusCode = response.response?.statusCode, statusCode >= 200 && statusCode < 300 {
                                if let data = response.data {
                                    let jsonData = JSON(data)
                                    
                                    if let metaDict = jsonData["meta"].dictionary {
                                        if let cobaltTimestamp = metaDict["cobaltTimestamp"]?.double {
                                            self?.collectionsByTenantTimestamp = Date(timeIntervalSince1970: cobaltTimestamp)
                                        }
                                    }
                                    
                                    var yardiRoommates: [YardiRoommate] = []
                                    if let otherOccupanctsArray = jsonData["included"].array {
                                        for otherOccupant in otherOccupanctsArray {
                                            if let type = otherOccupant["type"].string, type == "occupant" {
                                                if let roommate = self?.processYardiOtherOccupantFromFirebase(otherOccupant: otherOccupant) {
                                                    yardiRoommates.append(roommate)
                                                }
                                            }
                                        }
                                    }
                                    
                                    var yardiResidents: [YardiResident] = []
                                    var newCollectionsByTenant:[String: CobaltCollectionsByTenant] = [:]
                                    if let residentsArray = jsonData["data"].array {
                                        for residentData in residentsArray {
                                            if let type = residentData["type"].string, type == "resident" {
                                                if let resident = self?.processYardiResidentFromFirebase(residentData: residentData, yardiRoommates: yardiRoommates) {
                                                    if let yardiStatus = resident.YardiStatus, !IgnoredResidentYardiStatuses.contains(yardiStatus.lowercased()) {
                                                        yardiResidents.append(resident)
                                                    }
                                                }
                                                if let collectionsForTenant = self?.processCollectionsForTenantFromFirebase(residentData: residentData), let tenantCode = collectionsForTenant.tenantCode {
                                                    newCollectionsByTenant[tenantCode] = collectionsForTenant
                                                }
                                            }
                                        }
                                    }
                                    
                                    print("# of Firebase API Residents = \(yardiResidents.count)")
//                                    for resident in yardiResidents {
//                                        print(resident.ResidentID ?? resident.LastName ?? "?")
//                                    }
                                    
                                    self?.residents = yardiResidents
                                    self?.collectionsByTenant = newCollectionsByTenant
                                    self?.updateResidents()
                                    
                                } else {
                                    print("getYardiResidentsURLString - No Data")
                                }
                            } else {
                               let errorMessage = firebaseAPIErrorMessages(data: response.data, error: response.error, statusCode: response.response?.statusCode)
                               let alertController = UIAlertController(title: "Yardi Residents Error", message: errorMessage, preferredStyle: .alert)
                               let okayAction = UIAlertAction(title: "OK", style: .default)
                               alertController.addAction(okayAction)
                               self?.present(alertController, animated: true, completion: nil)
                            }
                            
                            dismissHUDForConnection()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: NOT USED - Get Residents from Yardi
    
//    func getCurrentResidents() {
//        guard let code = keyProperty?.property.code else {
//            print("ERROR: Missing property code for Yardi.")
//            return
//        }
//
//        #if RELEASE_BLUESTONE
//        let database = "gazv_live"
//        let server = "gazv_live"
//        #elseif RELEASE_STAGING
//        let database = "gazv_test"
//        let server = "gazv_test"
//        #else
//        let database = "gazv_test"
//        let server = "gazv_test"
//        #endif
//
//        let propertyCode = code
//        let xmlBody = "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><GetResident_Search xmlns=\"http://tempuri.org/YSI.Interfaces.WebServices/ItfServiceRequests\"><UserName>sapphire</UserName><Password>sapphire</Password><ServerName>\(server)</ServerName><Database>\(database)</Database><Platform>SQL Server</Platform><YardiPropertyId>\(propertyCode)</YardiPropertyId><InterfaceEntity>Sapphire Standard</InterfaceEntity><InterfaceLicense>MIIBEAYJKwYBBAGCN1gDoIIBATCB/gYKKwYBBAGCN1gDAaCB7zCB7AIDAgABAgJoAQICAIAEAAQQgoUIPFloyIysfjl7v+NuRASByIbcmZa2IpfLI/QX12F68yMaCNPYnciO/iVtkg+YaEsZc4OBdCgFzCb5hiZyOlgP5HRVHcB2IUSI3x1cKujMbf5e4psI+0rfdPf8HRsr8jaYf/7gn02JRSfmtjqk04ZAXSsmxXMPLhIcbDnrNZCgQqRigyqczT0ShoM3LJ+cSrmYOxPF/KCqklEXEFyrdvyFnfnu9MFf9nfex/oxd5DCSX+r32VJFaCO76YpnBmh5u+AK947xxF/lZAuPVMxnXuUUOdOfxnGgFIu</InterfaceLicense><Address></Address></GetResident_Search></soap:Body></soap:Envelope>"
//
//        let headers: HTTPHeaders = [
//            "Content-Type": "text/xml; charset=utf-8",
//            "Content-Length": "\(xmlBody.count)",
//            "SOAPAction": "http://tempuri.org/YSI.Interfaces.WebServices/ItfServiceRequests/GetResident_Search"
//        ]
//
//        AF.request("https://www.yardiasp14.com/21253beta/Webservices/itfServiceRequests.asmx", method: .post, parameters: nil, encoding: xmlBody, headers: headers)
//            .response { [weak self] (dataResponse) in
//                DispatchQueue.main.async { [weak self] in
//                    if let statusCode = dataResponse.response?.statusCode {
//                        if statusCode >= 400 {
//                            print("Yardi API Error: Status Code = \(statusCode)")
//                            self?.showMessagePrompt("Yardi API Error: Status Code = \(statusCode)")
//                        } else if let data = dataResponse.data {
//                            let xml = SWXMLHash.parse(data)
//                            let customers = xml["soap:Envelope"]["soap:Body"]["GetResident_SearchResponse"]["GetResident_SearchResult"]["CustomerSearch"]["Response"]["Customers"]["Customer"].all
//                            var newResidents:[YardiResident] = []
//                            if customers.count == 1, let error = customers[0]["ErrorMessages"]["Error"].element?.text {
//                                print("Yardi API Error: \(error)")
//                                self?.showMessagePrompt("Yardi API Error: \(error)")
//                            } else {
//                                for customer in customers {
//                                    if let resident = self?.processCustomer(customer: customer) {
//                                        if let yardiStatus = resident.YardiStatus, !IgnoredResidentYardiStatuses.contains(yardiStatus.lowercased()) {
//                                            newResidents.append(resident)
//                                        }
//                                    }
//                                }
//
//                                print("# of Yardi API Residents = \(newResidents.count)")
////                                for resident in newResidents {
////                                    print(resident.ResidentID ?? resident.LastName ?? "?")
////                                }
//
////                                self?.residents = newResidents
////                                self?.updateResidents()
//                            }
//                        }
//                    } else if let error = dataResponse.error {
//                        print("Yardi API Error: \(error.localizedDescription)")
//                        self?.showMessagePrompt("Yardi API Error: \(error.localizedDescription)")
//                    } else {
//                        print("Yardi API Error: Unknown")
//                        self?.showMessagePrompt("Yardi API Error: Unknown")
//                    }
//
//                    dismissHUDForConnection()
//                }
//        }
//    }
//
//    func processCustomer(customer: XMLIndexer) -> YardiResident {
//        var resident = YardiResident()
//
//        resident.ResidentID =   customer["Identification"]["IDValue"].element?.text
//        resident.Status =       customer["Identification"]["Status"].element?.text
//        resident.YardiStatus =  customer["Identification"]["YardiStatus"].element?.text
//
//        resident.FirstName =    customer["Name"]["FirstName"].element?.text
//        resident.MiddleName =   customer["Name"]["MiddleName"].element?.text
//        resident.LastName =     customer["Name"]["LastName"].element?.text
//
//        resident.Email =        customer["Address"]["Email"].element?.text
//
//        for child in customer["Phone"].children {
//            if let name = child.element?.name, let text = child.element?.text {
//                switch name.lowercased() {
//                    case "mobilenumber":
//                        resident.MobilePhone = text
//                    case "homenumber":
//                        resident.HomePhone = text
//                    case "officenumber":
//                        resident.OfficePhone = text
//                    default:
//                        print("Unmatched Phone Number Name: \(name)")
//                }
//            }
//        }
//
//        // Filter out duplicates
//        if let mobile = resident.MobilePhone {
//            if resident.HomePhone == mobile {
//                resident.HomePhone = nil
//            }
//            if resident.OfficePhone == mobile {
//                resident.OfficePhone = nil
//            }
//        }
//        if let home = resident.HomePhone {
//            if resident.OfficePhone == home {
//                resident.OfficePhone = nil
//            }
//        }
//
//        resident.UnitID =           customer["Lease"]["Identification"]["IDValue"].element?.text
//        resident.LeaseFromDate =    customer["Lease"]["LeaseFromDate"].element?.text
//        resident.LeaseToDate =      customer["Lease"]["LeaseToDate"].element?.text
//        resident.ActualMoveIn =     customer["Lease"]["ActualMoveIn"].element?.text
//        resident.UnitSqFt =         customer["Lease"]["UnitSqFt"].element?.text
//
//        var otherOccupants: [YardiRoommate] = []
//        for otherOccupant in customer["OtherOccupants"].all {
//            let roommate = processOtherOccupant(otherOccupant: otherOccupant)
//            otherOccupants.append(roommate)
//        }
//        resident.OtherOccupants = otherOccupants
//
//        return resident
//    }
//
//    func processOtherOccupant(otherOccupant: XMLIndexer) -> YardiRoommate {
//        var roommate = YardiRoommate()
//
//        roommate.RoommateID =   otherOccupant["Identification"]["IDValue"].element?.text
//        roommate.Relationship = otherOccupant["Identification"]["Relationship"].element?.text
//
//        roommate.FirstName =    otherOccupant["Name"]["FirstName"].element?.text
//        roommate.MiddleName =   otherOccupant["Name"]["MiddleName"].element?.text
//        roommate.LastName =     otherOccupant["Name"]["LastName"].element?.text
//
//        roommate.Email =        otherOccupant["Address"]["Email"].element?.text
//
//        for child in otherOccupant["Phone"].children {
//            if let name = child.element?.name, let text = child.element?.text {
//                switch name.lowercased() {
//                    case "mobilenumber":
//                        roommate.MobilePhone = text
//                    case "homenumber":
//                        roommate.HomePhone = text
//                    case "officenumber":
//                        roommate.OfficePhone = text
//                    default:
//                        print("Unmatched Phone Number Name: \(name)")
//                }
//            }
//        }
//
//        // Filter out duplicates
//        if let mobile = roommate.MobilePhone {
//            if roommate.HomePhone == mobile {
//                roommate.HomePhone = nil
//            }
//            if roommate.OfficePhone == mobile {
//                roommate.OfficePhone = nil
//            }
//        }
//        if let home = roommate.HomePhone {
//            if roommate.OfficePhone == home {
//                roommate.OfficePhone = nil
//            }
//        }
//
//        return roommate
//    }
    
    // MARK: Process Residents / Other Occupants (Firebase)
    
    func processYardiResidentFromFirebase(residentData: JSON, yardiRoommates: [YardiRoommate]) -> YardiResident? {
        var resident = YardiResident()
                
        guard let residentID = residentData["id"].string, residentID != "" else {
            return nil
        }
        resident.ResidentID = residentID
        
        if let value = residentData["attributes"]["status"].string, value != "" {
             resident.Status = value
        }
        if let value = residentData["attributes"]["yardiStatus"].string, value != "" {
             resident.YardiStatus = value
        }
        if let value = residentData["attributes"]["firstName"].string, value != "" {
             resident.FirstName = value
        }
        if let value = residentData["attributes"]["middleName"].string, value != "" {
             resident.MiddleName = value
        }
        if let value = residentData["attributes"]["lastName"].string, value != "" {
             resident.LastName = value
        }
        if let value = residentData["attributes"]["email"].string, value != "" {
            resident.Email = value
        }
        if let number = residentData["attributes"]["mobileNumber"].string, number != "" {
            resident.MobilePhone = number
        }
        if let number = residentData["attributes"]["homeNumber"].string, number != "" {
            resident.HomePhone = number
        }
        if let number = residentData["attributes"]["officeNumber"].string, number != "" {
            resident.OfficePhone = number
        }
        
        // Filter out duplicates
        if let mobile = resident.MobilePhone {
            if resident.HomePhone == mobile {
                resident.HomePhone = nil
            }
            if resident.OfficePhone == mobile {
                resident.OfficePhone = nil
            }
        }
        if let home = resident.HomePhone {
            if resident.OfficePhone == home {
                resident.OfficePhone = nil
            }
        }
        
        if let value = residentData["attributes"]["leaseUnit"].string, value != "" {
            resident.UnitID = value
        }
        if let value = residentData["attributes"]["leaseFrom"].string, value != "" {
            resident.LeaseFromDate = value
        }
        if let value = residentData["attributes"]["leaseTo"].string, value != "" {
            resident.LeaseToDate = value
        }
        if let value = residentData["attributes"]["moveIn"].string, value != "" {
             resident.ActualMoveIn = value
        }
        if let value = residentData["attributes"]["leaseSqFt"].string, value != "" {
             resident.UnitSqFt = value
        }

        let otherOccupants = yardiRoommates.filter( { $0.ResidentID == resident.ResidentID  } )
        resident.OtherOccupants = otherOccupants
        
        return resident
    }
    
    func processYardiOtherOccupantFromFirebase(otherOccupant: JSON) -> YardiRoommate? {
        var roommate = YardiRoommate()
        
        guard let residentID = otherOccupant["relationships"]["resident"]["data"]["id"].string, residentID != "" else {
            return nil
        }
        guard let roommateID = otherOccupant["id"].string, roommateID != "" else {
            return nil
        }
        
        roommate.ResidentID = residentID
        roommate.RoommateID = roommateID

        if let value = otherOccupant["attributes"]["relationship"].string, value != "" {
            roommate.Relationship = value
        }
        if let value = otherOccupant["attributes"]["firstName"].string, value != "" {
            roommate.FirstName = value
        }
        if let value = otherOccupant["attributes"]["middleName"].string, value != "" {
            roommate.MiddleName = value
        }
        if let value = otherOccupant["attributes"]["lastName"].string, value != "" {
            roommate.LastName = value
        }
        if let value = otherOccupant["attributes"]["Email"].string, value != "" {
            roommate.Email = value
        }
        if let number = otherOccupant["attributes"]["mobileNumber"].string, number != "" {
            roommate.MobilePhone = number
        }
        if let number = otherOccupant["attributes"]["homeNumber"].string, number != "" {
            roommate.HomePhone = number
        }
        if let number = otherOccupant["attributes"]["officeNumber"].string, number != "" {
            roommate.OfficePhone = number
        }
        
        // Filter out duplicates
        if let mobile = roommate.MobilePhone {
            if roommate.HomePhone == mobile {
                roommate.HomePhone = nil
            }
            if roommate.OfficePhone == mobile {
                roommate.OfficePhone = nil
            }
        }
        if let home = roommate.HomePhone {
            if roommate.OfficePhone == home {
                roommate.OfficePhone = nil
            }
        }
        
        return roommate
    }
    
    // MARK: NOT USED - Cobalt API Call
    
//    func getCollectionsByTenant() {
//        guard let url = cobaltGetCollectionsByTenant() else {
//            print("CollectionsByTenant API Error: Missing URL.")
//            return
//        }
//
//        guard let code = keyProperty?.property.code else {
//            print("CollectionsByTenant API Error: Missing property code.")
//            return
//        }
//
//        let params = [
//            "property_code" : code,
//            "token" : ""
//        ]
//        let headers: HTTPHeaders = [
//            "Content-Type": "application/json; charset=utf-8"
//        ]
//
//        AF.request(url, method: .get, parameters: params, headers: headers)
//            .response { [weak self] (dataResponse) in
//                DispatchQueue.main.async { [weak self] in
//                    if let statusCode = dataResponse.response?.statusCode {
//                        if statusCode >= 400 {
//                            if let error = dataResponse.error {
//                                print("CollectionsByTenant API Error: \(error.localizedDescription)")
//                                self?.showMessagePrompt("CollectionsByTenant API Error: \(error.localizedDescription)")
//                            } else if let data = dataResponse.data {
//                                let jsonData = JSON(data)
//                                if let errorMessage = jsonData["error"].string {
//                                    print("CollectionsByTenant API Error: \(errorMessage)")
//                                    self?.showMessagePrompt("CollectionsByTenant API Error: \(errorMessage)")
//                                } else {
//                                    print("CollectionsByTenant API Error: Status Code = \(statusCode)")
//                                    self?.showMessagePrompt("CollectionsByTenant API Error: Status Code = \(statusCode)")
//                                }
//                            } else {
//                                print("CollectionsByTenant API Error: Status Code = \(statusCode)")
//                                self?.showMessagePrompt("CollectionsByTenant API Error: Status Code = \(statusCode)")
//                            }
//                        } else if let data = dataResponse.data {
//                            let jsonData = JSON(data)
//                            if let timestamp = jsonData["timestamp"].double {
//                                self?.collectionsByTenantTimestamp = Date.init(timeIntervalSince1970: timestamp)
//                                var newCollectionsByTenant:[String: CobaltCollectionsByTenant] = [:]
//                                if let data = jsonData["data"].array {
//                                    for datum in data {
//
//                                        if let tenant = self?.processCollectionsForTenant(datum: datum), let tenantCode = tenant.tenantCode {
//                                            newCollectionsByTenant[tenantCode] = tenant
//                                        }
//                                    }
//
//                                        self?.collectionsByTenant = newCollectionsByTenant
//                                        self?.updateResidents()
//                                }
//                            }
//                        }
//                    } else if let error = dataResponse.error {
//                        print("CollectionsByTenant API Error: \(error.localizedDescription)")
//                        self?.showMessagePrompt("CollectionsByTenant API Error: \(error.localizedDescription)")
//                    } else {
//                        print("CollectionsByTenant API Error: Unknown")
//                        self?.showMessagePrompt("CollectionsByTenant API Error: Unknown")
//                    }
//                }
//        }
//
//        return
//    }
//
//    func processCollectionsForTenant(datum: JSON) -> CobaltCollectionsByTenant {
//        var tenant = CobaltCollectionsByTenant()
//
//        tenant.tenantCode = datum["tenant_code"].string
//        if let value = datum["total_charges"].string {
//            tenant.totalCharges = Double(value)
//        }
//        if let value = datum["total_owed"].string {
//            tenant.totalOwed = Double(value)
//        }
//        tenant.paymentPlan  = datum["payment_plan"].bool
//        tenant.eviction     = datum["eviction"].bool
//        tenant.lastNote     = datum["last_note"].string
//        tenant.paymentPlanDelinquent = datum["payment_plan_delinquent"].bool
//        if let lastNoteUpdatedAt = datum["last_note_updated_at"].string {
//            let dateFormatter = DateFormatter()
//            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
//            if let date = dateFormatter.date(from: lastNoteUpdatedAt) {
//                tenant.lastNoteUpdatedAt = date
//            }
//        }
//
//        return tenant
//    }
    
    // MARK: Process Collections per Resident (Firebase)
    
    func processCollectionsForTenantFromFirebase(residentData: JSON) -> CobaltCollectionsByTenant? {
        var tenant = CobaltCollectionsByTenant()
        
        guard let tenantCode = residentData["id"].string, tenantCode != "" else {
            return nil
        }
        guard let totalOwed = residentData["attributes"]["totalOwed"].number, totalOwed.doubleValue > 0 else {
            return nil
        }
        tenant.tenantCode = tenantCode
        tenant.totalOwed = totalOwed.doubleValue
        tenant.totalCharges = residentData["attributes"]["totalCharges"].numberValue.doubleValue
        tenant.paymentPlan = residentData["attributes"]["totalCharges"].boolValue
        tenant.eviction = residentData["attributes"]["totalCharges"].boolValue
        if let value = residentData["attributes"]["lastNote"].string, value != "" {
            tenant.lastNote = value
        }
        tenant.paymentPlanDelinquent = residentData["attributes"]["paymentPlanDelinquent"].boolValue
        if let lastNoteUpdatedAt = residentData["attributes"]["lastNoteUpdatedAt"].string {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = dateFormatter.date(from: lastNoteUpdatedAt) {
                tenant.lastNoteUpdatedAt = date
            }
        }
        
        return tenant
    }
    
    // MARK: Format Data
    
    func formatResidentData(resident: YardiResident) -> NSAttributedString {

        let boldBlue: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: GlobalColors.darkBlue]
        let bold: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: UIColor.black]
        let regular: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]

        let string = NSMutableAttributedString(string: "", attributes: regular)

        string.append(NSAttributedString(string: "Name:", attributes: boldBlue))
        string.append(NSAttributedString(string: " \(resident.FirstName ?? "")", attributes: bold))
        if let middleName = resident.MiddleName {
            string.append(NSAttributedString(string: " \(middleName)", attributes: bold))
        }
        string.append(NSAttributedString(string: " \(resident.LastName ?? "")\n", attributes: bold))
        
        string.append(NSAttributedString(string: "Unit:", attributes: boldBlue))
        string.append(NSAttributedString(string: " \(resident.UnitID ?? "")", attributes: regular))
        if let sqft = resident.UnitSqFt {
            let value = Double(sqft) ?? 0.0
            string.append(NSAttributedString(string: ", ", attributes: regular))
            string.append(NSAttributedString(string: "SqFt:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(Int(value))\n", attributes: regular))
        } else {
            string.append(NSAttributedString(string: "\n", attributes: regular))
        }

//        string.append(NSAttributedString(string: "Address:\n", attributes: bold))
//        string.append(NSAttributedString(string: "    \(resident.Address1 ?? "")\n", attributes: regular))
//        if let address2 = resident.Address2 {
//            string.append(NSAttributedString(string: "    \(address2)\n", attributes: regular))
//        }
//        string.append(NSAttributedString(string: "    \(resident.City ?? ""), \(resident.State ?? "") \(resident.PostalCode ?? "")\n", attributes: regular))

        string.append(NSAttributedString(string: "Email:", attributes: boldBlue))
        string.append(NSAttributedString(string: " \(resident.Email ?? "")\n", attributes: regular))
        
        if let number = resident.MobilePhone {
            string.append(NSAttributedString(string: "Mobile:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(number)\n", attributes: regular))
        }
        if let number = resident.HomePhone {
            string.append(NSAttributedString(string: "Home:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(number)\n", attributes: regular))
        }
        if let number = resident.OfficePhone {
            string.append(NSAttributedString(string: "Office:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(number)\n", attributes: regular))
        }

        if let value = resident.LeaseFromDate {
            string.append(NSAttributedString(string: "LeaseFromDate:", attributes: boldBlue))
            let date = value.replacingOccurrences(of: "T00:00:00", with: "")
            string.append(NSAttributedString(string: " \(date)\n", attributes: regular))
        }
        if let value = resident.LeaseToDate {
            string.append(NSAttributedString(string: "LeaseToDate:", attributes: boldBlue))
            let date = value.replacingOccurrences(of: "T00:00:00", with: "")
            string.append(NSAttributedString(string: " \(date)\n", attributes: regular))
        }
        if let value = resident.ActualMoveIn {
            string.append(NSAttributedString(string: "ActualMoveIn:", attributes: boldBlue))
            let date = value.replacingOccurrences(of: "T00:00:00", with: "")
            string.append(NSAttributedString(string: " \(date)\n", attributes: regular))
        }
        
        if let roommates = resident.OtherOccupants, roommates.count > 0 {
            string.append(NSAttributedString(string: "\nRoommate(s):\n", attributes: boldBlue))
            for roommate in roommates {
                string.append(formatRoommateData(roommate: roommate))
            }
        }
        
        if let tenantCode = resident.ResidentID,  let collections = collectionsByTenant[tenantCode] {
            string.append(formatCollections(collections: collections))
        }

        return string
    }
    
    func formatRoommateData(roommate: YardiRoommate) -> NSAttributedString {

        let boldBlue: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: GlobalColors.darkBlue]
        let bold: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: UIColor.black]
        let regular: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]

        let string = NSMutableAttributedString(string: "", attributes: regular)

        string.append(NSAttributedString(string: "Name:", attributes: boldBlue))
        string.append(NSAttributedString(string: " \(roommate.FirstName ?? "")", attributes: bold))
        if let middleName = roommate.MiddleName {
            string.append(NSAttributedString(string: " \(middleName)", attributes: bold))
        }
        string.append(NSAttributedString(string: " \(roommate.LastName ?? "")\n", attributes: bold))
        
        if let value = roommate.Relationship, value != "" {
            string.append(NSAttributedString(string: "Relationship:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(value)\n", attributes: regular))
        }
        
        if let value = roommate.Email, value != "" {
            string.append(NSAttributedString(string: "Email:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(value)\n", attributes: regular))
        }
        
        if let number = roommate.MobilePhone {
            string.append(NSAttributedString(string: "Mobile:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(number)\n", attributes: regular))
        }
        if let number = roommate.HomePhone {
            string.append(NSAttributedString(string: "Home:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(number)\n", attributes: regular))
        }
        if let number = roommate.OfficePhone {
            string.append(NSAttributedString(string: "Office:", attributes: boldBlue))
            string.append(NSAttributedString(string: " \(number)\n", attributes: regular))
        }

        return string
    }
    
    func formatCollections(collections: CobaltCollectionsByTenant) -> NSAttributedString {

        let boldRed: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: UIColor.red]
        let bold: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12), NSAttributedString.Key.foregroundColor: UIColor.black]
        let regular: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]

        let string = NSMutableAttributedString(string: "", attributes: regular)
        
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        
        string.append(NSAttributedString(string: "\n", attributes: regular))

        string.append(NSAttributedString(string: "Total Charges:", attributes: boldRed))
        if let totalCharges = collections.totalCharges {
            if let value = currencyFormatter.string(from: NSNumber(value: totalCharges)) {
                string.append(NSAttributedString(string: " \(value)\n", attributes: bold))
            } else {
                string.append(NSAttributedString(string: " <data missing>\n", attributes: regular))
            }
        } else {
            string.append(NSAttributedString(string: " <data missing>\n", attributes: regular))
        }
        
        string.append(NSAttributedString(string: "Total Owed:", attributes: boldRed))
        if let totalCharges = collections.totalOwed {
            if let value = currencyFormatter.string(from: NSNumber(value: totalCharges)) {
                string.append(NSAttributedString(string: " \(value)\n", attributes: bold))
            } else {
                string.append(NSAttributedString(string: " <data missing>\n", attributes: regular))
            }
        } else {
            string.append(NSAttributedString(string: " <data missing>\n", attributes: regular))
        }
        
        string.append(NSAttributedString(string: "Payment Plan:", attributes: boldRed))
        if let hasPaymentPlan = collections.paymentPlan {
            if hasPaymentPlan {
                string.append(NSAttributedString(string: " YES\n", attributes: bold))
            } else {
                string.append(NSAttributedString(string: " NO\n", attributes: regular))
            }
        } else {
            string.append(NSAttributedString(string: " Unknown\n", attributes: regular))
        }
        
        string.append(NSAttributedString(string: "Payment Plan Delinquent:", attributes: boldRed))
        if let isPaymentPlanDelinquent = collections.paymentPlanDelinquent {
            if isPaymentPlanDelinquent {
                string.append(NSAttributedString(string: " YES\n", attributes: bold))
            } else {
                string.append(NSAttributedString(string: " NO\n", attributes: regular))
            }
        } else {
            string.append(NSAttributedString(string: " Unknown\n", attributes: regular))
        }
        
        string.append(NSAttributedString(string: "Eviction:", attributes: boldRed))
        if let hasEviction = collections.eviction {
            if hasEviction {
                string.append(NSAttributedString(string: " YES\n", attributes: bold))
            } else {
                string.append(NSAttributedString(string: " NO\n", attributes: regular))
            }
        } else {
            string.append(NSAttributedString(string: " Unknown\n", attributes: regular))
        }
        
        string.append(NSAttributedString(string: "Note(s):", attributes: boldRed))
        if let lastNote = collections.lastNote {
            string.append(NSAttributedString(string: " \(lastNote)\n", attributes: regular))
        } else {
            string.append(NSAttributedString(string: " \n", attributes: regular))
        }


        return string
    }

    
    // MARK: UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterString = searchText
        updateResidents()
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
    
    func filterResidents() {
        if filterString != "" {
            filteredResidents = residents.filter({
                formatResidentData(resident: $0).string.lowercased().contains(filterString.lowercased()) ||
                ($0.ResidentID ?? "").lowercased().contains(filterString.lowercased()) ||
                ($0.YardiStatus ?? "").lowercased().contains(filterString.lowercased())
            })
        } else {
            filteredResidents = residents
        }
        
        // Implement Status Filter
        switch currentFilter {
            case .all:
                // Do nothing, no filtering
                break
            default:
                filteredResidents = filteredResidents.filter({
                    $0.YardiStatus == currentFilter.rawValue
                })
        }
    }
    
    func updateResidents() {
                
        filterResidents()
        var residentsAfterFilter = filteredResidents
        
        let highValue = "zzzz"
        let lowValue = "aaaa"

        // Apply sorting
        switch currentSort {
            case .unitID:
                print("sorted by unitID")
                residentsAfterFilter.sort { ($0.UnitID ?? highValue).lowercased() <= ($1.UnitID ?? highValue).lowercased()  }
            case .residentID:
                print("sorted by residentID")
                residentsAfterFilter.sort { ($0.ResidentID ?? highValue).lowercased() <= ($1.ResidentID ?? highValue).lowercased() }
            case .residentFirstName:
                print("sorted by residentFirstName")
                residentsAfterFilter.sort { ($0.FirstName ?? highValue).lowercased()  <= ($1.FirstName ?? highValue).lowercased() }
            case .residentLastName:
                print("sorted by residentLastName")
                residentsAfterFilter.sort { ($0.LastName ?? highValue).lowercased() <= ($1.LastName ?? highValue).lowercased() }
            case .status:
                print("sorted by status")
                residentsAfterFilter.sort { ($0.YardiStatus ?? lowValue).lowercased() > ($1.YardiStatus ?? lowValue).lowercased() }
        }
        
        residentsFilteredAndSorted = residentsAfterFilter
        updateResidentsWithCollectinos()
        tableView.reloadData()
    }
    
    func updateResidentsWithCollectinos() {
        var newResidentsWithCollections: [ResidentWithCollections] = []
        for resident in residentsFilteredAndSorted {
            if let tenantCode = resident.ResidentID {
                if let collections = collectionsByTenant[tenantCode] {
                    let newResidentWithCollections = ResidentWithCollections(resident: resident, collections: collections)
                    newResidentsWithCollections.append(newResidentWithCollections)
                }
            }

        }
        
        residentsWithCollections = newResidentsWithCollections
    }
        
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        let collectionsExist = residentsWithCollections.count > 0
        if collectionsExist {
            return 2
        }
        
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let collectionsExist = residentsWithCollections.count > 0
        switch (collectionsExist, section) {
        case (true, 0):
            return residentsWithCollections.count
        default:
            return residentsFilteredAndSorted.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "workOrderCell")! as! WorkOrderTVCell

        var resident: YardiResident?
        var collections: CobaltCollectionsByTenant?
        
        let collectionsExist = residentsWithCollections.count > 0
        switch (collectionsExist, indexPath.section) {
        case (true, 0):
            let residentWithCollection = residentsWithCollections[indexPath.row]
            resident = residentWithCollection.resident
            collections = residentWithCollection.collections
        default:
            resident = residentsFilteredAndSorted[indexPath.row]
            if let resident = resident, let tenantCode = resident.ResidentID {
                collections = collectionsByTenant[tenantCode]
            }
        }
        
        if let resident = resident {
            cell.idCreatedAtLabel.text = " \(resident.ResidentID ?? "<no id>") "
            cell.statusLabel.text = " \(resident.YardiStatus ?? "<Unknown Status>") "
        }
        
        let attributedText = NSMutableAttributedString()
        if let resident = resident {
            attributedText.append(formatResidentData(resident: resident))
        }
        cell.propertiesLabel.attributedText = attributedText
        
        if collections != nil {
            cell.delinquentLabel.isHidden = false
        } else {
            cell.delinquentLabel.isHidden = true
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Dequeue with the reuse identifier
        let cell = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: "PropertySectionHeader")
        let header = cell as! PropertySectionHeader
        
        let collectionsExist = residentsWithCollections.count > 0
        switch (collectionsExist, section) {
        case (true, 0):
            if let lastUpdate = collectionsByTenantTimestamp {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, h:mm a"
                header.titleLabel.text = " Collections (Updated: \(dateFormatter.string(from: lastUpdate)))"
            } else {
                header.titleLabel.text = " Collections (No Data)"
            }
        default:
            header.titleLabel.text = " Residents"
        }
        
        header.background.backgroundColor = UIColor.darkGray
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        let collectionsExist = residentsWithCollections.count > 0
        switch (collectionsExist, indexPath.section) {
        case (true, 0):
            let resident = residentsWithCollections[indexPath.row].resident
            presentAlertOptionsFor(resident: resident, indexPath: indexPath)
        default:
            let resident = residentsFilteredAndSorted[indexPath.row]
            presentAlertOptionsFor(resident: resident, indexPath: indexPath)
        }
    }
    
    func presentAlertOptionsFor(resident: YardiResident, indexPath: IndexPath) {
        
        let canDeviceEmail = MFMailComposeViewController.canSendMail()
        var canDeviceCall = false
        if let url = URL(string: "tel://"), UIApplication.shared.canOpenURL(url) {
            canDeviceCall = true
        }
        
        if !canDeviceEmail && !canDeviceCall {
            let alertController = UIAlertController(title: "Unsupported Action", message: "Calling and emailing are not options on this device.", preferredStyle: .alert)
            let okayAction = UIAlertAction(title: "OK", style: .default) { action in
            }
            alertController.addAction(okayAction)
            present(alertController, animated: true, completion: nil)
            return
        }

        // Selection : {ResidentAction : Value}
        var selections: [String: ResidentAction] = [:]
        var order: Int = 0
        
        var residentName = resident.FirstName ?? ""
        if let value = resident.MiddleName {
            residentName += " " + value
        }
        if let value = resident.LastName {
            residentName += " " + value
        }
        if let email = resident.Email, email != "", canDeviceEmail {
            let section = residentName + " - Email"
            let action = ResidentAction(order: order, action: .email, value: email)
            selections[section] = action
            order += 1
        }
        if canDeviceCall {
            if let phone = resident.MobilePhone {
                let section = residentName + " - " + phone + " (M)"
                let action = ResidentAction(order: order, action: .call, value: phone)
                selections[section] = action
                order += 1
            }
            if let phone = resident.HomePhone {
                let section = residentName + " - " + phone + " (H)"
                let action = ResidentAction(order: order, action: .call, value: phone)
                selections[section] = action
                order += 1
            }
            if let phone = resident.OfficePhone {
                let section = residentName + " - " + phone + " (O)"
                let action = ResidentAction(order: order, action: .call, value: phone)
                selections[section] = action
                order += 1
            }
        }
        
        if let roommates = resident.OtherOccupants, roommates.count > 0 {
            for roommate in roommates {
                var roommateName = roommate.FirstName ?? ""
                if let value = roommate.MiddleName {
                    roommateName += " " + value
                }
                if let value = roommate.LastName {
                    roommateName += " " + value
                }
                if let email = roommate.Email, email != "", canDeviceEmail {
                    let section = roommateName + " - Email"
                    let action = ResidentAction(order: order, action: .email, value: email)
                    selections[section] = action
                    order += 1
                }
                if canDeviceCall {
                    if let phone = roommate.MobilePhone {
                        let section = roommateName + " - " + phone + " (M)"
                        let action = ResidentAction(order: order, action: .call, value: phone)
                        selections[section] = action
                        order += 1
                    }
                    if let phone = roommate.HomePhone {
                        let section = roommateName + " - " + phone + " (H)"
                        let action = ResidentAction(order: order, action: .call, value: phone)
                        selections[section] = action
                        order += 1
                    }
                    if let phone = roommate.OfficePhone {
                        let section = roommateName + " - " + phone + " (O)"
                        let action = ResidentAction(order: order, action: .call, value: phone)
                        selections[section] = action
                        order += 1
                    }
                }
            }
        }
                
        
        let actionsMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        for selection in selections.sorted(by: { $0.value.order < $1.value.order }) {
            let action = UIAlertAction(title: selection.key, style: .default, handler: { [weak self] (action) in
                self?.handleSelection(residentAction: selection.value)
            })
            actionsMenu.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            
        })
        actionsMenu.addAction(cancelAction)
        
        // iPad support only
        if let popoverPresentationController = actionsMenu.popoverPresentationController {
            let cellRect = tableView.rectForRow(at: indexPath)
            popoverPresentationController.sourceView = tableView
            popoverPresentationController.sourceRect = cellRect
            popoverPresentationController.permittedArrowDirections  = .any
        }
        
        present(actionsMenu, animated: true, completion: nil)
    }
    
    func handleSelection(residentAction: ResidentAction) {
        if residentAction.action == .call {
            if let url = URL(string: "tel://\(residentAction.value.digits)"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                let alertController = UIAlertController(title: "Phone number unsupported", message: nil, preferredStyle: .alert)
                let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                }
                alertController.addAction(okayAction)
                present(alertController, animated: true, completion: nil)
            }
        } else if residentAction.action == .email {
            if MFMailComposeViewController.canSendMail() {
                let mail = MFMailComposeViewController()
                mail.mailComposeDelegate = self
                mail.setToRecipients([residentAction.value])
                mail.setMessageBody("", isHTML: false)
                present(mail, animated: true)
            } else {
                let alertController = UIAlertController(title: "Email unsupported", message: nil, preferredStyle: .alert)
                let okayAction = UIAlertAction(title: "OK", style: .default) { action in
                }
                alertController.addAction(okayAction)
                present(alertController, animated: true, completion: nil)
            }
        }
    }
        
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

    }
 
    
    func setObservers() {
        if let user = currentUser {
            userListener = dbDocumentUserWith(userId: user.uid).addSnapshotListener({ [weak self] (documentSnapshot, error) in
                DispatchQueue.main.async {
                    print("Current User Profile Updated, observed by PropertyResidentsVC")
                    self?.adminCorporateUser = false
                    if let document = documentSnapshot, document.exists {
                        if let profile = Mapper<UserProfile>().map(JSONObject: document.data()), !profile.isDisabled {
                            let admin = profile.admin
                            let corporate = profile.corporate
                            self?.adminCorporateUser = admin || corporate
                        }
                    }
                }
            })
        }
        
        presentHUDForConnection()
    }
}
